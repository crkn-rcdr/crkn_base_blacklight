#!/usr/bin/env ruby
# frozen_string_literal: true

# Seed a local development Redis with the compact download cache used by
# DownloadsController. This is intentionally not a Windmill script.
#
# Default output:
#
#   download:summary
#   download:manifest_ids
#   download:manifest:{manifest_ark}
#
# Manifest records use schema crkn-download-cache-v4:
#
#   {
#     "schema": "crkn-download-cache-v4",
#     "generated_at": "2026-08-26T12:00:00Z",
#     "full_pdf_available": true,
#     "full_pdf_route": { "repository": "access" },
#     "page_pdf_available": true,
#     "page_pdf_routes": "a0p",
#     "page_pdf_preservation_paths": { "3": "aip/example-page.pdf" },
#     "canvas_noids": ["69429/c0123456789"]
#   }
#
# page_pdf_routes is one character per canvas: a=access, p=preservation, 0=none.
# Access PDF object paths are derived by Blacklight from noids. Preservation PDF
# object paths are stored because they cannot always be derived from the slug.

$stdout.sync = true
$stderr.sync = true

require 'base64'
require 'json'
require 'net/http'
require 'optparse'
require 'set'
require 'socket'
require 'time'
require 'uri'

def load_env_defaults!
  root_dir = File.expand_path('..', __dir__)
  ['.env.dev', '.env'].each do |filename|
    path = File.join(root_dir, filename)
    next unless File.file?(path)

    File.foreach(path) do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')

      key, val = line.split('=', 2)
      next if key.nil? || val.nil?

      key = key.strip
      val = val.strip
      val = val[1..-2] if (val.start_with?('"') && val.end_with?('"')) || (val.start_with?("'") && val.end_with?("'"))
      ENV[key] ||= val unless key.empty?
    end
  end
end

load_env_defaults!

DEFAULT_REDIS_URL = ENV['DOWNLOAD_CACHE_REDIS_URL'] || "redis://127.0.0.1:#{ENV.fetch('DOWNLOAD_CACHE_REDIS_PORT', '7001')}/0"
DEFAULT_COUCH_URL = ENV['COUCH_BASE_URL'] || ENV['COUCHDB_URL'] || 'http://trepat.tor.c7a.ca:5984'
DEFAULT_SAMPLE_SLUGS = ['oocihm.13566'].freeze
DEFAULT_BATCH_SIZE = 500
DEFAULT_REDIS_PIPELINE_SIZE = 100

PORTAL_ALIASES = {
  'www' => 'canadiana'
}.freeze

PORTAL_CONFIGS = {
  'canadiana' => {
    host: 'www',
    blacklight_core: 'blacklight_marc',
    solr_urls: [
      ENV['SOLR_URL'] || 'http://10.202.1.33:8983/solr/blacklight_marc',
      'http://10.202.1.32:8983/solr/blacklight_marc'
    ].compact.uniq,
    access_db: ENV['COUCH_ACCESS_DB'] || 'access',
    canvas_db: ENV['COUCH_CANVAS_DB'] || 'canvas',
    presentation_db: ENV['COUCH_PRESENTATION_DB'] || 'copresentation2',
    sample_id_prefix: ENV['DOWNLOAD_CACHE_ID_PREFIX'] || 'oocihm.135',
    sample_slugs: DEFAULT_SAMPLE_SLUGS
  },
  'heritage' => {
    host: 'heritage',
    blacklight_core: 'blacklight_marc',
    solr_urls: [],
    access_db: 'access',
    canvas_db: 'canvas',
    presentation_db: 'copresentation2'
  },
  'gac' => {
    host: 'gac',
    blacklight_core: 'blacklight_marc',
    solr_urls: [],
    access_db: 'access',
    canvas_db: 'canvas',
    presentation_db: 'copresentation2'
  },
  'nrcan' => {
    host: 'nrcan',
    blacklight_core: 'blacklight_marc',
    solr_urls: [],
    access_db: 'access',
    canvas_db: 'canvas',
    presentation_db: 'copresentation2'
  },
  'pub' => {
    host: 'pub',
    blacklight_core: 'blacklight_marc',
    solr_urls: [],
    access_db: 'access',
    canvas_db: 'canvas',
    presentation_db: 'copresentation2'
  },
  'sve' => {
    host: 'sve',
    blacklight_core: 'blacklight_marc',
    solr_urls: [],
    access_db: 'access',
    canvas_db: 'canvas',
    presentation_db: 'copresentation2'
  },
  'parl' => {
    host: 'parl',
    blacklight_core: 'blacklight_marc',
    solr_urls: [],
    access_db: 'access',
    canvas_db: 'canvas',
    presentation_db: 'copresentation2'
  },
  'mcgillarchives' => {
    host: 'mcgillarchives',
    blacklight_core: 'blacklight_marc',
    solr_urls: [],
    access_db: 'access',
    canvas_db: 'canvas',
    presentation_db: 'copresentation2'
  }
}.freeze

class JsonHttp
  def initialize(timeout:)
    @timeout = timeout
  end

  def get_json(url, headers: {})
    request_json(Net::HTTP::Get, url, headers: headers)
  end

  def post_json(url, body, headers: {})
    request_json(Net::HTTP::Post, url, body: body, headers: headers)
  end

  private

  def request_json(request_class, url, body: nil, headers: {})
    uri = URI(url)
    request = request_class.new(uri)
    headers.each { |key, value| request[key] = value }

    if body
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(body)
    end

    response = Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: @timeout,
      read_timeout: @timeout
    ) { |http| http.request(request) }

    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    when Net::HTTPNotFound
      nil
    when Net::HTTPUnauthorized, Net::HTTPForbidden
      :unauthorized
    else
      raise "HTTP #{response.code} from #{uri}: #{response.body[0, 300]}"
    end
  end
end

class RedisError < StandardError; end

class RedisClient
  def initialize(url:)
    @uri = URI(url)
    @socket = TCPSocket.new(@uri.host, @uri.port || 6379)
    authenticate
    select_db
  end

  def ping
    command('PING')
  end

  def set(key, value)
    command('SET', key, value)
  end

  def sadd(key, value)
    command('SADD', key, value)
  end

  def del(*keys)
    return 0 if keys.empty?

    command('DEL', *keys)
  end

  def unlink(*keys)
    return 0 if keys.empty?

    command('UNLINK', *keys)
  end

  def smembers(key)
    Array(command('SMEMBERS', key))
  end

  def rename(old_key, new_key)
    command('RENAME', old_key, new_key)
  end

  def scan_each(match:, count:)
    return enum_for(:scan_each, match: match, count: count) unless block_given?

    cursor = '0'

    loop do
      cursor, keys = command('SCAN', cursor, 'MATCH', match, 'COUNT', count.to_i)
      Array(keys).each { |key| yield key }
      break if cursor == '0'
    end
  end

  def pipelined
    pipeline = RedisPipeline.new(self)
    yield pipeline
    pipeline.execute
  end

  def raw_pipeline(commands)
    return [] if commands.empty?

    @socket.write(commands.map { |parts| encode_command(parts) }.join)
    commands.map { read_reply }
  end

  def command(*parts)
    @socket.write(encode_command(parts))
    read_reply
  end

  private

  def authenticate
    password = @uri.password
    return if password.nil? || password.empty?

    if @uri.user && !@uri.user.empty?
      command('AUTH', URI.decode_www_form_component(@uri.user), URI.decode_www_form_component(password))
    else
      command('AUTH', URI.decode_www_form_component(password))
    end
  end

  def select_db
    db = @uri.path.to_s.sub(%r{\A/}, '')
    command('SELECT', db) unless db.empty?
  end

  def encode_command(parts)
    payload = +"*#{parts.length}\r\n"
    parts.each do |part|
      value = part.to_s.b
      payload << "$#{value.bytesize}\r\n#{value}\r\n"
    end
    payload
  end

  def read_reply
    prefix = @socket.read(1)
    raise RedisError, 'Connection closed by Redis' if prefix.nil?

    case prefix
    when '+'
      read_line
    when '-'
      raise RedisError, read_line
    when ':'
      read_line.to_i
    when '$'
      read_bulk_string
    when '*'
      read_array
    else
      raise RedisError, "Unexpected Redis response prefix: #{prefix.inspect}"
    end
  end

  def read_line
    @socket.gets("\r\n").to_s.delete_suffix("\r\n")
  end

  def read_bulk_string
    length = read_line.to_i
    return nil if length.negative?

    value = @socket.read(length)
    @socket.read(2)
    value
  end

  def read_array
    length = read_line.to_i
    return nil if length.negative?

    Array.new(length) { read_reply }
  end
end

class RedisPipeline
  def initialize(client)
    @client = client
    @commands = []
  end

  def set(key, value)
    @commands << ['SET', key, value]
  end

  def sadd(key, value)
    @commands << ['SADD', key, value]
  end

  def execute
    @client.raw_pipeline(@commands)
  end
end

class CouchClient
  attr_reader :access_db, :canvas_db, :presentation_db

  def initialize(base_url:, username:, password:, access_db:, canvas_db:, presentation_db:, timeout:, batch_size:)
    @base_url = base_url.to_s.sub(%r{/+\z}, '')
    @access_db = access_db
    @canvas_db = canvas_db
    @presentation_db = presentation_db
    @http = JsonHttp.new(timeout: timeout)
    @batch_size = [batch_size.to_i, 1].max
    @headers = {}

    if username.to_s != '' && password.to_s != ''
      token = Base64.strict_encode64("#{username}:#{password}")
      @headers['Authorization'] = "Basic #{token}"
    end
  end

  def get(db, key)
    response = @http.get_json("#{db_url(db)}/#{escape_key(key)}", headers: @headers)
    response == :unauthorized ? nil : response
  end

  def get_many(db, keys)
    keys = keys.compact.map(&:to_s).map(&:strip).reject(&:empty?).uniq
    return {} if keys.empty?

    keys.each_slice(@batch_size).each_with_object({}) do |chunk, out|
      response = @http.post_json(
        "#{db_url(db)}/_all_docs?include_docs=true",
        { keys: chunk },
        headers: @headers
      )
      next if response == :unauthorized || !response.is_a?(Hash)

      response.fetch('rows', []).each do |row|
        doc = row['doc']
        next unless doc.is_a?(Hash)

        doc_id = row['id'] || doc['_id']
        out[doc_id] = doc if doc_id
      end
    end
  end

  def accessible?(db)
    response = @http.get_json(db_url(db), headers: @headers)
    response.is_a?(Hash)
  end

  private

  def db_url(db)
    "#{@base_url}/#{escape_key(db)}"
  end

  def escape_key(value)
    URI.encode_www_form_component(value.to_s).gsub('+', '%20')
  end
end

def first_scalar(value)
  case value
  when nil
    nil
  when Array
    value.filter_map { |item| first_scalar(item) }.first
  when Hash
    %w[id @id value].filter_map { |key| first_scalar(value[key]) }.first
  else
    text = value.to_s.strip
    text.empty? ? nil : text
  end
end

def normalize_ark(raw)
  value = first_scalar(raw)
  return nil if value.nil?

  value = value.strip
  return value.split('/manifest/', 2).last.delete_prefix('/').delete_suffix('/') if value.include?('/manifest/')
  return value.split('/canvas/', 2).last.delete_prefix('/').delete_suffix('/') if value.include?('/canvas/')
  return value.split('ark:/', 2).last.delete_prefix('/').delete_suffix('/') if value.include?('ark:/')

  if value.start_with?('http')
    parts = URI(value).path.split('/').reject(&:empty?)
    parts.each_with_index do |part, index|
      return "#{part}/#{parts[index + 1]}" if part.match?(/\A\d+\z/) && parts[index + 1]
    end
  end

  value.delete_prefix('/').delete_suffix('/')
rescue URI::InvalidURIError
  value.delete_prefix('/').delete_suffix('/')
end

def canvas_noid?(value)
  noid = normalize_ark(value)
  return false unless noid&.include?('/')

  noid.split('/', 2).last.downcase.start_with?('c')
end

def canvas_ids_from_access(access_doc)
  Array(access_doc&.fetch('canvases', nil)).filter_map do |canvas|
    canvas_id = first_scalar(canvas)
    noid = normalize_ark(canvas_id)
    canvas_noid?(noid) ? noid : nil
  end
end

def ordered_page_keys(presentation_doc)
  out = []
  seen = Set.new

  Array(presentation_doc&.fetch('order', nil)).each do |raw_key|
    key = raw_key.to_s.strip
    next if key.empty? || seen.include?(key)

    out << key
    seen << key
  end

  components = presentation_doc&.fetch('components', nil)
  return out unless components.is_a?(Hash)

  components.keys.map(&:to_s).sort_by do |key|
    match = key.match(/\.(\d+)\z/)
    match ? [0, match[1].to_i] : [1, key]
  end.each do |raw_key|
    key = raw_key.strip
    next if key.empty? || seen.include?(key)

    out << key
    seen << key
  end

  out
end

def component_record(presentation_doc, page_key)
  components = presentation_doc&.fetch('components', nil)
  return {} unless components.is_a?(Hash)

  component = components[page_key]
  component.is_a?(Hash) ? component : {}
end

def valid_ocr_pdf?(record, expected_noid: nil)
  return false unless record.is_a?(Hash)

  ocr_pdf = record['ocrPdf']
  return false unless ocr_pdf.is_a?(Hash)

  noid = normalize_ark(record['noid'] || record['_id'])
  extension = first_scalar(ocr_pdf['extension']) || first_scalar(record['canonicalDownloadExtension'])
  return false unless noid && extension&.downcase == 'pdf'
  return false if expected_noid && noid != expected_noid

  true
end

def canonical_download_path(record, prefer_file_path: false)
  return nil unless record.is_a?(Hash)

  if prefer_file_path && record.key?('file')
    file = record['file']
    file_path = first_scalar(file['path']) if file.is_a?(Hash)
    return file_path if file_path
  end

  first_scalar(record['canonicalDownload'])
end

def legacy_component_pdf_available?(record, expected_noid:)
  return false unless record.is_a?(Hash)

  noid = normalize_ark(record['noid'])
  extension = first_scalar(record['canonicalDownloadExtension'])
  noid == expected_noid && extension&.downcase == 'pdf' && canvas_noid?(noid)
end

def full_pdf_route(access_doc, presentation_doc, manifest_id)
  return { 'repository' => 'access' } if valid_ocr_pdf?(access_doc, expected_noid: manifest_id)
  return { 'repository' => 'access' } if valid_ocr_pdf?(presentation_doc, expected_noid: manifest_id)

  object_path = canonical_download_path(presentation_doc, prefer_file_path: true)
  return { 'repository' => 'preservation', 'object_path' => object_path } if object_path

  nil
end

def page_pdf_route(page_doc, legacy_component, canvas_doc, page_noid)
  object_path = canonical_download_path(page_doc)
  return { 'repository' => 'preservation', 'object_path' => object_path } if object_path
  return { 'repository' => 'access' } if valid_ocr_pdf?(page_doc, expected_noid: page_noid)

  object_path = canonical_download_path(legacy_component)
  return { 'repository' => 'preservation', 'object_path' => object_path } if object_path
  return { 'repository' => 'access' } if valid_ocr_pdf?(legacy_component, expected_noid: page_noid)
  return { 'repository' => 'access' } if legacy_component_pdf_available?(legacy_component, expected_noid: page_noid)

  return { 'repository' => 'access' } if valid_ocr_pdf?(canvas_doc, expected_noid: page_noid)

  nil
end

def route_code(route)
  case route&.fetch('repository', nil)
  when 'access' then 'a'
  when 'preservation' then 'p'
  else '0'
  end
end

def normalize_portal(value)
  portal = value.to_s.strip.downcase
  portal = 'canadiana' if portal.empty?
  PORTAL_ALIASES.fetch(portal, portal)
end

def portal_config(portal)
  config = PORTAL_CONFIGS[portal]
  return config if config

  known = PORTAL_CONFIGS.keys.sort.join(', ')
  raise "Unknown portal #{portal.inspect}. Known portals: #{known}"
end

def normalize_url_values(value)
  candidates =
    case value
    when nil
      []
    when Array
      value
    else
      value.to_s.tr("\n", ',').split(',')
    end

  candidates.map(&:to_s).map(&:strip).reject(&:empty?).uniq
end

def normalize_solr_core_url(url, core)
  url = url.to_s.strip.sub(%r{/+\z}, '')
  return '' if url.empty?

  url = "http://#{url}" unless url.include?('://')
  uri = URI(url)
  path = uri.path.sub(%r{/+\z}, '')

  if path.end_with?("/#{core}")
    uri.path = path
  elsif path.end_with?('/solr')
    uri.path = "#{path}/#{core}"
  elsif !path.include?('/solr/')
    uri.path = "#{path}/solr/#{core}"
  end

  uri.query = nil
  uri.fragment = nil
  uri.to_s.sub(%r{/+\z}, '')
rescue URI::InvalidURIError
  ''
end

def normalize_solr_select_url(url)
  url = url.to_s.strip.sub(%r{/+\z}, '')
  url.end_with?('/select') ? url : "#{url}/select"
end

def normalize_id_prefix(prefix)
  value = prefix.to_s.strip
  return nil if value.empty? || value == '*'

  value = value[0...-1] if value.end_with?('*') && !value[0...-1].match?(/[*?]/)
  raise 'Use a plain prefix or one trailing wildcard, like oocihm.lac*' if value.match?(/[*?]/)

  value.empty? ? nil : value
end

def solr_phrase(value)
  value.to_s.gsub(/["\\]/) { |char| "\\#{char}" }
end

def query_solr_url(http, solr_url, params)
  uri = URI(normalize_solr_select_url(solr_url))
  uri.query = URI.encode_www_form(params)
  response = http.get_json(uri.to_s)
  raise "Invalid Solr response from #{solr_url}" unless response.is_a?(Hash)

  response
end

def choose_solr_url(http, solr_urls, core)
  normalized_urls = normalize_url_values(solr_urls).filter_map do |url|
    normalized = normalize_solr_core_url(url, core)
    normalized.empty? ? nil : normalized
  end.uniq
  raise 'At least one Solr URL is required' if normalized_urls.empty?

  last_error = nil
  normalized_urls.each do |solr_url|
    begin
      query_solr_url(http, solr_url, [['q', '*:*'], ['rows', 0], ['wt', 'json']])
      puts "[INFO] Connected Solr target #{solr_url}"
      return solr_url
    rescue StandardError => e
      last_error = e
      warn "[WARN] Solr target failed #{solr_url}: #{e.message}"
    end
  end

  raise "No Solr targets were reachable: #{last_error&.message}"
end

def solr_search_params(id_prefix, batch_size, cursor_mark)
  params = [
    ['q', '*:*'],
    ['fq', 'ark:[* TO *]'],
    ['fl', 'id,ark,is_serial'],
    ['rows', batch_size],
    ['sort', 'id asc'],
    ['cursorMark', cursor_mark],
    ['wt', 'json']
  ]

  prefix = normalize_id_prefix(id_prefix)
  if prefix
    params << ['fq', '{!prefix f=id v=$id_prefix}']
    params << ['id_prefix', prefix]
  end

  params
end

def each_solr_doc(http, solr_url, id_prefix, batch_size)
  cursor_mark = '*'
  first_page = true

  loop do
    response = query_solr_url(http, solr_url, solr_search_params(id_prefix, batch_size, cursor_mark))
    docs = Array(response.dig('response', 'docs'))

    if first_page
      puts "[INFO] Solr matched #{response.dig('response', 'numFound') || docs.length} docs"
      first_page = false
    end

    docs.each { |doc| yield doc }
    next_cursor_mark = response['nextCursorMark']

    break if docs.empty? || next_cursor_mark.nil? || next_cursor_mark == cursor_mark

    cursor_mark = next_cursor_mark
  end
end

def required_slug_docs(http, solr_url, required_slugs)
  normalize_url_values(required_slugs).each_with_object({}) do |slug, out|
    response = query_solr_url(
      http,
      solr_url,
      [
        ['q', "id:\"#{solr_phrase(slug)}\""],
        ['fq', 'ark:[* TO *]'],
        ['fl', 'id,ark,is_serial'],
        ['rows', 1],
        ['wt', 'json']
      ]
    )
    Array(response.dig('response', 'docs')).each { |doc| out[doc['id']] = doc if doc['id'] }
  end
end

def build_record(doc, access_docs, presentation_docs, page_docs, canvas_docs, generated_at)
  slug = first_scalar(doc['id'])
  manifest_id = normalize_ark(doc['ark'])
  return nil unless slug && manifest_id

  access_doc = access_docs[manifest_id]
  presentation_doc = presentation_docs[slug]
  page_keys = ordered_page_keys(presentation_doc)

  canvas_noids =
    if page_keys.any?
      page_keys.filter_map do |page_key|
        page_doc = page_docs[page_key] || {}
        legacy_component = component_record(presentation_doc, page_key)
        page_noid = normalize_ark(page_doc['noid']) || normalize_ark(legacy_component['noid'])
        canvas_noid?(page_noid) ? page_noid : nil
      end
    else
      canvas_ids_from_access(access_doc)
    end

  return nil if canvas_noids.empty?

  full_route = full_pdf_route(access_doc, presentation_doc, manifest_id)
  preservation_paths = {}
  page_routes = []

  canvas_noids.each_with_index do |page_noid, index|
    page_key = page_keys[index]
    page_doc = page_key ? page_docs[page_key] || {} : {}
    legacy_component = page_key ? component_record(presentation_doc, page_key) : {}
    canvas_doc = canvas_docs[page_noid] || {}
    route = page_pdf_route(page_doc, legacy_component, canvas_doc, page_noid)
    code = route_code(route)

    page_routes << code
    preservation_paths[(index + 1).to_s] = route['object_path'] if code == 'p'
  end

  record = {
    '_manifest_id' => manifest_id,
    'schema' => 'crkn-download-cache-v4',
    'generated_at' => generated_at,
    'full_pdf_available' => !full_route.nil?,
    'page_pdf_available' => page_routes.any? { |code| code != '0' },
    'page_pdf_routes' => page_routes.join,
    'canvas_noids' => canvas_noids
  }
  record['full_pdf_route'] = full_route if full_route
  record['page_pdf_preservation_paths'] = preservation_paths if preservation_paths.any?
  record
end

def records_for_batch(couch, docs, presentation_enabled, generated_at)
  manifest_ids_by_slug = {}
  docs.each do |doc|
    slug = first_scalar(doc['id'])
    manifest_id = normalize_ark(doc['ark'])
    manifest_ids_by_slug[slug] = manifest_id if slug && manifest_id
  end

  access_docs = couch.get_many(couch.access_db, manifest_ids_by_slug.values)
  presentation_docs = presentation_enabled ? couch.get_many(couch.presentation_db, manifest_ids_by_slug.keys) : {}

  page_keys = presentation_docs.values.flat_map { |doc| ordered_page_keys(doc) }.uniq
  page_docs = presentation_enabled ? couch.get_many(couch.presentation_db, page_keys) : {}

  canvas_docs =
    if presentation_enabled
      {}
    else
      canvas_noids = access_docs.values.flat_map { |doc| canvas_ids_from_access(doc) }
      couch.get_many(couch.canvas_db, canvas_noids.uniq)
    end

  docs.filter_map do |doc|
    build_record(doc, access_docs, presentation_docs, page_docs, canvas_docs, generated_at)
  end
end

def page_route_counts(record)
  routes = record['page_pdf_routes'].to_s
  {
    access: routes.count('a'),
    preservation: routes.count('p')
  }
end

def add_record_stats!(stats, record)
  stats[:total_cached] += 1
  stats[:total_canvases] += Array(record['canvas_noids']).length
  stats[:total_full_pdfs] += 1 if record['full_pdf_available']

  if record['full_pdf_available']
    case record.dig('full_pdf_route', 'repository')
    when 'preservation'
      stats[:total_full_pdf_preservation] += 1
    else
      stats[:total_full_pdf_access] += 1
    end
  end

  page_counts = page_route_counts(record)
  stats[:total_page_pdf_access] += page_counts[:access]
  stats[:total_page_pdf_preservation] += page_counts[:preservation]
  stats[:total_page_pdfs] += page_counts[:access] + page_counts[:preservation]
end

def local_redis_url?(redis_url)
  host = URI(redis_url).host
  ['127.0.0.1', 'localhost', 'redis'].include?(host)
rescue URI::InvalidURIError
  false
end

def redis_payload(record)
  JSON.generate(record.reject { |key, _value| key.start_with?('_') })
end

def write_records(redis, records, manifest_ids_key, dry_run)
  return if records.empty?

  if dry_run
    puts "[DRY RUN] Would write #{records.length} manifest records and add IDs to #{manifest_ids_key}"
    return
  end

  redis.pipelined do |pipe|
    records.each do |record|
      manifest_id = record['_manifest_id']
      pipe.set("download:manifest:#{manifest_id}", redis_payload(record))
      pipe.sadd(manifest_ids_key, manifest_id)
    end
  end
end

def clear_download_cache(redis, redis_url, force_clear_remote)
  unless local_redis_url?(redis_url) || force_clear_remote
    raise "Refusing to clear non-local Redis #{redis_url}. Pass --force-clear-remote if you really mean it."
  end

  keys = redis.scan_each(match: 'download:*', count: 500).to_a
  keys.each_slice(500) do |chunk|
    redis.unlink(*chunk)
  rescue RedisError
    redis.del(*chunk)
  end
  keys.length
end

def reset_next_manifest_ids(redis, dry_run)
  if dry_run
    puts '[DRY RUN] Would reset download:manifest_ids:next'
  else
    redis.del('download:manifest_ids:next')
  end
end

def cleanup_stale_records(redis, stale_manifest_ids)
  stale_manifest_ids.to_a.each_slice(500).sum do |ids|
    keys = ids.map { |manifest_id| "download:manifest:#{manifest_id}" }
    begin
      redis.unlink(*keys)
    rescue RedisError
      redis.del(*keys)
    end
  end
end

def publish_cache(redis, summary, full_refresh, dry_run)
  if dry_run
    if full_refresh
      puts '[DRY RUN] Would publish download:summary and replace download:manifest_ids'
    else
      puts '[DRY RUN] Would publish download:last_partial_seed'
    end
    return
  end

  payload = JSON.generate(summary)

  unless full_refresh
    redis.set('download:last_partial_seed', payload)
    return
  end

  old_ids = redis.smembers('download:manifest_ids').to_set
  new_ids = redis.smembers('download:manifest_ids:next').to_set
  stale_ids = old_ids - new_ids

  if stale_ids.any?
    deleted = cleanup_stale_records(redis, stale_ids)
    puts "[INFO] Cleaned #{deleted} stale Redis manifest records"
  end

  redis.set('download:summary', payload)

  if new_ids.any?
    redis.rename('download:manifest_ids:next', 'download:manifest_ids')
  else
    redis.del('download:manifest_ids')
    redis.del('download:manifest_ids:next')
  end
end

def default_solr_urls(options, config)
  return options[:solr_urls] if options[:solr_urls]

  config[:solr_urls]
end

def env_suffix(portal)
  portal.to_s.upcase.gsub(/[^A-Z0-9]+/, '_')
end

def configured_value(value)
  return nil if value.nil?
  return nil if value.respond_to?(:empty?) && value.empty?

  return value unless value.is_a?(String)

  stripped = value.strip
  stripped.empty? ? nil : stripped
end

def portal_env(base_name, portal)
  configured_value(ENV["#{base_name}_#{env_suffix(portal)}"])
end

def redis_url_for_portal(options, portal)
  configured_value(options[:redis_url]) ||
    portal_env('DOWNLOAD_CACHE_REDIS_URL', portal) ||
    configured_value(ENV['DOWNLOAD_CACHE_REDIS_URL']) ||
    DEFAULT_REDIS_URL
end

def solr_urls_for_portal(options, config, portal)
  configured_value(options[:solr_urls]) ||
    portal_env('DOWNLOAD_CACHE_SOLR_URLS', portal) ||
    configured_value(ENV['DOWNLOAD_CACHE_SOLR_URLS']) ||
    configured_value(ENV['SOLR_URL']) ||
    default_solr_urls(options, config)
end

def couch_db_for_portal(options, option_key, env_name, config, config_key, portal)
  configured_value(options[option_key]) ||
    portal_env(env_name, portal) ||
    configured_value(ENV[env_name]) ||
    config[config_key]
end

def print_portals
  payload = PORTAL_CONFIGS.each_with_object({}) do |(portal, config), out|
    suffix = env_suffix(portal)
    out[portal] = {
      host: config[:host],
      blacklight_core: config[:blacklight_core],
      env: {
        redis_url: "DOWNLOAD_CACHE_REDIS_URL_#{suffix}",
        solr_urls: "DOWNLOAD_CACHE_SOLR_URLS_#{suffix}",
        access_db: "COUCH_ACCESS_DB_#{suffix}",
        canvas_db: "COUCH_CANVAS_DB_#{suffix}",
        presentation_db: "COUCH_PRESENTATION_DB_#{suffix}"
      },
      built_in_solr_urls: config[:solr_urls]
    }
  end

  puts JSON.pretty_generate(payload)
end

def sample_keys(records, sample_manifest_keys)
  records.each do |record|
    break if sample_manifest_keys.length >= 5

    sample_manifest_keys << "download:manifest:#{record['_manifest_id']}"
  end
end

def sample_id_prefix(config)
  config[:sample_id_prefix] || '*'
end

def sample_slugs(config)
  normalize_url_values(config[:sample_slugs])
end

options = {
  portal: ENV.fetch('DOWNLOAD_CACHE_PORTAL', 'canadiana'),
  redis_url: nil,
  solr_urls: nil,
  couch_url: ENV['COUCH_BASE_URL'] || ENV['COUCHDB_URL'] || DEFAULT_COUCH_URL,
  couch_user: ENV['COUCH_USERNAME'] || ENV['COUCHDB_USER'],
  couch_password: ENV['COUCH_PASSWORD'] || ENV['COUCHDB_PASSWORD'],
  access_db: ENV['COUCH_ACCESS_DB'],
  canvas_db: ENV['COUCH_CANVAS_DB'],
  presentation_db: ENV['COUCH_PRESENTATION_DB'],
  id_prefix: ENV.fetch('DOWNLOAD_CACHE_ID_PREFIX', 'oocihm.135'),
  max_docs: ENV.fetch('DOWNLOAD_CACHE_MAX_DOCS', '25').to_i,
  required_slugs: normalize_url_values(ENV['DOWNLOAD_CACHE_SLUGS']),
  batch_size: ENV.fetch('DOWNLOAD_CACHE_BATCH_SIZE', DEFAULT_BATCH_SIZE.to_s).to_i,
  couch_batch_size: ENV.fetch('COUCH_DOC_BATCH_SIZE', '1000').to_i,
  redis_pipeline_size: ENV.fetch('DOWNLOAD_CACHE_REDIS_PIPELINE_SIZE', DEFAULT_REDIS_PIPELINE_SIZE.to_s).to_i,
  clear: false,
  force_clear_remote: false,
  allow_empty_full_refresh: false,
  timeout: ENV.fetch('DOWNLOAD_CACHE_HTTP_TIMEOUT', '60').to_i,
  dry_run: false,
  list_portals: false,
  sample: false,
  skip_serial_parents: true
}

OptionParser.new do |parser|
  parser.banner = 'Usage: bundle exec ruby script/seed_download_cache.rb [options]'

  parser.on('--portal NAME', 'Portal name for defaults and summary metadata') { |value| options[:portal] = value }
  parser.on('--redis-url URL', 'Redis URL to seed') { |value| options[:redis_url] = value }
  parser.on('--solr-urls URLS', 'Comma-separated Solr core/select URLs') { |value| options[:solr_urls] = value }
  parser.on('--couch-url URL', 'CouchDB base URL') { |value| options[:couch_url] = value }
  parser.on('--couch-user USER', 'CouchDB username') { |value| options[:couch_user] = value }
  parser.on('--couch-password PASSWORD', 'CouchDB password') { |value| options[:couch_password] = value }
  parser.on('--access-db NAME', 'CouchDB access database') { |value| options[:access_db] = value }
  parser.on('--canvas-db NAME', 'CouchDB canvas database') { |value| options[:canvas_db] = value }
  parser.on('--presentation-db NAME', 'CouchDB presentation database') { |value| options[:presentation_db] = value }
  parser.on('--id-prefix PREFIX', 'Solr id prefix; use * for the whole core') { |value| options[:id_prefix] = value }
  parser.on('--max-docs N', Integer, 'Maximum non-serial Solr docs to seed; 0 means no limit') { |value| options[:max_docs] = value }
  parser.on('--batch-size N', Integer, 'Solr docs to process per batch') { |value| options[:batch_size] = value }
  parser.on('--couch-batch-size N', Integer, 'Couch _all_docs keys per request') { |value| options[:couch_batch_size] = value }
  parser.on('--redis-pipeline-size N', Integer, 'Redis records per pipeline write') { |value| options[:redis_pipeline_size] = value }
  parser.on('--slug SLUG', 'Include a specific slug; can be repeated') { |value| options[:required_slugs] << value }
  parser.on('--sample', 'Seed a small portal-specific dev sample instead of the whole core') { options[:sample] = true }
  parser.on('--full', 'Seed the full portal core') do
    options[:id_prefix] = '*'
    options[:max_docs] = 0
    options[:required_slugs] = []
  end
  parser.on('--clear', 'Delete existing download:* keys before seeding; local Redis only unless forced') { options[:clear] = true }
  parser.on('--force-clear-remote', 'Allow --clear against non-local Redis') { options[:force_clear_remote] = true }
  parser.on('--allow-empty-full-refresh', 'Allow a full refresh to publish zero cached records') { options[:allow_empty_full_refresh] = true }
  parser.on('--dry-run', 'Build records but do not write Redis') { options[:dry_run] = true }
  parser.on('--list-portals', 'Print supported portal names and per-portal env vars') { options[:list_portals] = true }
  parser.on('--no-skip-serial-parents', 'Include serial-level Blacklight docs') { options[:skip_serial_parents] = false }
end.parse!

if options[:list_portals]
  print_portals
  exit
end

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
generated_at = Time.now.utc.iso8601
portal = normalize_portal(options[:portal])
config = portal_config(portal)
portal_host = config[:host]
blacklight_core = config[:blacklight_core]
redis_url = redis_url_for_portal(options, portal)
solr_urls = solr_urls_for_portal(options, config, portal)

if options[:sample]
  options[:id_prefix] = sample_id_prefix(config)
  options[:max_docs] = 25
  options[:required_slugs] = sample_slugs(config)
end

id_prefix = options[:id_prefix]
id_prefix_normalized = normalize_id_prefix(id_prefix)
batch_size = [options[:batch_size].to_i, 1].max
redis_pipeline_size = [options[:redis_pipeline_size].to_i, 1].max
max_docs = [options[:max_docs].to_i, 0].max
required_slugs = normalize_url_values(options[:required_slugs])
full_refresh = id_prefix_normalized.nil? && max_docs.zero? && required_slugs.empty?
manifest_ids_key = full_refresh ? 'download:manifest_ids:next' : 'download:manifest_ids'
http = JsonHttp.new(timeout: options[:timeout])

selected_solr_url = choose_solr_url(http, solr_urls, blacklight_core)

redis = nil
unless options[:dry_run]
  redis = RedisClient.new(url: redis_url)
  redis.ping
  puts "[INFO] Connected Redis target #{redis_url}"
end

couch = CouchClient.new(
  base_url: options[:couch_url],
  username: options[:couch_user],
  password: options[:couch_password],
  access_db: couch_db_for_portal(options, :access_db, 'COUCH_ACCESS_DB', config, :access_db, portal),
  canvas_db: couch_db_for_portal(options, :canvas_db, 'COUCH_CANVAS_DB', config, :canvas_db, portal),
  presentation_db: couch_db_for_portal(options, :presentation_db, 'COUCH_PRESENTATION_DB', config, :presentation_db, portal),
  timeout: options[:timeout],
  batch_size: options[:couch_batch_size]
)

presentation_enabled = couch.accessible?(couch.presentation_db)
warn "[WARN] #{couch.presentation_db} is not accessible; preservation canonical routes will be skipped." unless presentation_enabled

puts(
  '[INFO] Starting Redis download cache seed ' \
  "| portal=#{portal} " \
  "| host=#{portal_host} " \
  "| core=#{blacklight_core} " \
  "| solr=#{selected_solr_url} " \
  "| couch=#{options[:couch_url]} " \
  "| access_db=#{couch.access_db} " \
  "| canvas_db=#{couch.canvas_db} " \
  "| presentation_db=#{couch.presentation_db} " \
  "| id_prefix=#{id_prefix} " \
  "| max_docs=#{max_docs} " \
  "| full_refresh=#{full_refresh} " \
  "| dry_run=#{options[:dry_run]}"
)

if options[:clear] && !options[:dry_run]
  deleted = clear_download_cache(redis, redis_url, options[:force_clear_remote])
  puts "[INFO] Cleared #{deleted} existing download:* Redis keys"
end

reset_next_manifest_ids(redis, options[:dry_run]) if full_refresh

stats = {
  total_seen: 0,
  total_selected: 0,
  total_cached: 0,
  total_skipped: 0,
  total_errors: 0,
  total_canvases: 0,
  total_full_pdfs: 0,
  total_full_pdf_access: 0,
  total_full_pdf_preservation: 0,
  total_page_pdfs: 0,
  total_page_pdf_access: 0,
  total_page_pdf_preservation: 0
}
docs_batch = []
pending_records = []
sample_manifest_keys = []
required_docs_by_id = required_slug_docs(http, selected_solr_url, required_slugs)
seen_doc_ids = Set.new

flush_pending = lambda do
  write_records(redis, pending_records, manifest_ids_key, options[:dry_run])
  pending_records = []
end

process_batch = lambda do |batch|
  return if batch.empty?

  puts "[INFO] Processing manifest batch | count=#{batch.length}"

  begin
    records = records_for_batch(couch, batch, presentation_enabled, generated_at)
    records.each do |record|
      sample_keys([record], sample_manifest_keys)
      add_record_stats!(stats, record)
      pending_records << record

      flush_pending.call if pending_records.length >= redis_pipeline_size
    end
    stats[:total_skipped] += batch.length - records.length
  rescue StandardError => e
    stats[:total_errors] += batch.length
    warn "[WARN] Failed to process manifest batch: #{e.class}: #{e.message}"
  end
end

enqueue_doc = lambda do |doc|
  doc_id = first_scalar(doc['id'])
  return if doc_id.nil? || seen_doc_ids.include?(doc_id)

  seen_doc_ids << doc_id
  stats[:total_seen] += 1

  if options[:skip_serial_parents] && first_scalar(doc['is_serial']).to_s.downcase == 'yes'
    stats[:total_skipped] += 1
    return
  end

  docs_batch << doc
  stats[:total_selected] += 1
  reached_limit = max_docs.positive? && stats[:total_selected] >= max_docs

  if docs_batch.length >= batch_size || reached_limit
    process_batch.call(docs_batch)
    docs_batch = []
  end

  if stats[:total_selected].positive? && (stats[:total_selected] % 1000).zero?
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    puts(
      '[INFO] Progress ' \
      "| seen=#{stats[:total_seen]} " \
      "| selected=#{stats[:total_selected]} " \
      "| cached=#{stats[:total_cached]} " \
      "| canvases=#{stats[:total_canvases]} " \
      "| errors=#{stats[:total_errors]} " \
      "| elapsed_s=#{elapsed.round(1)}"
    )
  end
end

required_docs_by_id.values.each do |doc|
  break if max_docs.positive? && stats[:total_selected] >= max_docs

  enqueue_doc.call(doc)
end

unless max_docs.positive? && stats[:total_selected] >= max_docs
  each_solr_doc(http, selected_solr_url, id_prefix, batch_size) do |doc|
    break if max_docs.positive? && stats[:total_selected] >= max_docs

    enqueue_doc.call(doc)
  end
end

process_batch.call(docs_batch)
flush_pending.call

elapsed_seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(3)
summary = {
  schema: 'crkn-download-cache-summary-v1',
  generated_at: generated_at,
  portal_host: portal_host,
  blacklight_core: blacklight_core,
  solr_url: selected_solr_url,
  manifest_base: "https://#{portal_host}-iiif-pres.canadiana.ca/manifest",
  availability_source: presentation_enabled ? "dev:couch:#{couch.access_db}+#{couch.presentation_db}" : "dev:couch:#{couch.access_db}+#{couch.canvas_db}",
  id_prefix: id_prefix,
  total_seen: stats[:total_seen],
  total_selected: stats[:total_selected],
  total_cached: stats[:total_cached],
  total_skipped: stats[:total_skipped],
  total_errors: stats[:total_errors],
  total_canvases: stats[:total_canvases],
  total_full_pdfs: stats[:total_full_pdfs],
  total_full_pdf_access: stats[:total_full_pdf_access],
  total_full_pdf_preservation: stats[:total_full_pdf_preservation],
  total_page_pdfs: stats[:total_page_pdfs],
  total_page_pdf_access: stats[:total_page_pdf_access],
  total_page_pdf_preservation: stats[:total_page_pdf_preservation],
  elapsed_seconds: elapsed_seconds,
  full_refresh: full_refresh
}

if full_refresh && stats[:total_selected].positive? && stats[:total_cached].zero? && !options[:allow_empty_full_refresh]
  raise(
    'Refusing to publish an empty full refresh after selecting ' \
    "#{stats[:total_selected]} Solr docs. Check Couch access, then rerun; " \
    'pass --allow-empty-full-refresh only if this is intentional.'
  )
end

publish_cache(redis, summary, full_refresh, options[:dry_run])

puts JSON.pretty_generate(
  dry_run: options[:dry_run],
  redis_url: redis_url,
  selected_solr_url: selected_solr_url,
  presentation_enabled: presentation_enabled,
  summary: summary,
  sample_manifest_keys: sample_manifest_keys
)
