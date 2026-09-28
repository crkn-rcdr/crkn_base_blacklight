require 'connection_pool'
require 'json'
require 'openssl'
require 'redis'
require 'uri'

class DownloadsController < ApplicationController
  MAX_TOKEN_TTL = 30 * 60

  class << self
    attr_writer :download_cache_pool

    def download_cache_pool
      @download_cache_pool ||= ConnectionPool.new(
        size: download_cache_pool_size,
        timeout: download_cache_timeout
      ) do
        Redis.new(
          url: download_cache_redis_url,
          connect_timeout: download_cache_timeout,
          read_timeout: download_cache_timeout,
          write_timeout: download_cache_timeout
        )
      end
    end

    private

    def download_cache_redis_url
      Rails.configuration.x.download_cache_redis_url.to_s
    end

    def download_cache_pool_size
      size = Rails.configuration.x.download_cache_redis_pool_size.to_i
      size.positive? ? size : 5
    end

    def download_cache_timeout
      timeout = Rails.configuration.x.download_cache_redis_timeout.to_f
      timeout.positive? ? timeout : 1.0
    end
  end

  def index
    slug = params[:id].to_s
    manifest_id = normalize_ark(params[:ark])
    page_num = current_page_num

    record = download_cache_record(manifest_id)
    canvas_noids = Array(record['canvas_noids']).filter_map { |value| normalize_noid(value) }
    canvas_noid = canvas_noids[page_num - 1]

    full_pdf_uri = if truthy?(record['full_pdf_available'])
                     full_pdf_uri_for(record, slug, manifest_id)
                   else
                     ''
                   end
    page_pdf_uri = canvas_noid.present? ? page_pdf_uri_for(record, canvas_noid, slug, page_num) : ''

    render json: {
      "docPdfUri" => full_pdf_uri,
      "pagePdfUri" => page_pdf_uri,
      "pageImgUri" => canvas_noid.present? ? image_download_uri(canvas_noid, slug, page_num) : '',
      "pageNum" => page_num,
      "pageCount" => canvas_noids.length,
      "cacheHit" => record.present?
    }
  end

  private

  def download_cache_record(manifest_id)
    return {} if manifest_id.blank?

    raw_record = nil
    self.class.download_cache_pool.with do |redis|
      raw_record = redis.get("download:manifest:#{manifest_id}")
    end

    record = raw_record.present? ? JSON.parse(raw_record) : {}
    record.is_a?(Hash) ? record : {}
  rescue JSON::ParserError, Redis::BaseError, ConnectionPool::Error, ConnectionPool::TimeoutError => e
    Rails.logger.warn("DownloadsController download cache error for #{manifest_id}: #{e.class}: #{e.message}") if defined?(Rails)
    {}
  end

  def normalize_ark(raw_ark)
    value = raw_ark.to_s.strip
    return '' if value.blank?

    value = value.split('/manifest/', 2).last if value.include?('/manifest/')
    value = value.split('/canvas/', 2).last if value.include?('/canvas/')
    value = value.split('ark:/', 2).last if value.include?('ark:/')

    value.sub(%r{\A/+}, '').sub(%r{/+\z}, '')
  end

  def normalize_noid(raw_noid)
    value = raw_noid.to_s.strip
    return nil if value.blank?

    URI.decode_www_form_component(value).sub(%r{\A/+}, '').sub(%r{/+\z}, '')
  rescue ArgumentError
    value.sub(%r{\A/+}, '').sub(%r{/+\z}, '')
  end

  def current_page_num
    page_num = params[:pageNum].to_i
    page_num.positive? ? page_num : 1
  end

  def truthy?(value)
    value == true || value.to_s.match?(/\A(?:true|1|yes)\z/i)
  end

  def page_pdf_available?(record, page_num)
    routes = record['page_pdf_routes'].to_s
    return %w[a p].include?(routes[page_num - 1]) if routes.present?

    statuses = record['page_pdf_statuses'].to_s
    return statuses[page_num - 1] == '1' if statuses.present?

    truthy?(record['page_pdf_available'])
  end

  def full_pdf_uri_for(record, slug, manifest_id)
    routed_uri = signed_pdf_route_uri(record['full_pdf_route'], "#{manifest_id}.pdf", "#{slug}.pdf")
    return routed_uri if routed_uri.present?
    return '' if record['schema'].to_s == 'crkn-download-cache-v4'

    if record['schema'].to_s == 'crkn-download-cache-v3'
      signed_access_pdf_uri("#{manifest_id}.pdf", "#{slug}.pdf")
    else
      signed_item_pdf_uri(slug, manifest_id)
    end
  end

  def page_pdf_uri_for(record, canvas_noid, slug, page_num)
    routed_uri = signed_pdf_route_uri(page_pdf_route(record, page_num), "#{canvas_noid}.pdf", "#{slug}.#{page_num}.pdf")
    return routed_uri if routed_uri.present?
    return '' if record['page_pdf_routes'].to_s.present?

    return signed_access_pdf_uri("#{canvas_noid}.pdf", "#{slug}.#{page_num}.pdf") if page_pdf_available?(record, page_num)

    ''
  end

  def page_pdf_route(record, page_num)
    routes = record['page_pdf_routes'].to_s
    return nil if routes.blank?

    case routes[page_num - 1]
    when 'a'
      { 'repository' => 'access' }
    when 'p'
      paths = record['page_pdf_preservation_paths']
      object_path = paths[page_num.to_s] if paths.is_a?(Hash)
      { 'repository' => 'preservation', 'object_path' => object_path }
    end
  end

  def signed_pdf_route_uri(route, fallback_object_path, filename)
    return '' unless route.is_a?(Hash)

    repository = route['repository'].presence || route['repo'].presence
    return '' unless %w[access preservation].include?(repository)

    object_path = route['object_path'].presence || route['path'].presence
    object_path ||= fallback_object_path if repository == 'access'
    return '' if object_path.blank?

    signed_object_pdf_uri(
      repository,
      object_path,
      repository == 'access' ? filename : route['filename'].presence
    )
  end

  def signed_item_pdf_uri(slug, noid)
    return '' if slug.blank? || noid.blank? || download_token_secret.blank?

    expires = token_expires
    query = {
      slug: slug,
      noid: noid,
      type: 'PDF',
      expires: expires,
      sig: item_signature(slug, noid, 'PDF', [], expires)
    }

    "#{download_endpoint}?#{URI.encode_www_form(query)}"
  end

  def signed_access_pdf_uri(object_path, filename)
    signed_object_pdf_uri('access', object_path, filename)
  end

  def signed_object_pdf_uri(repository, object_path, filename = nil)
    return '' if object_path.blank? || download_token_secret.blank?

    expires = token_expires
    filename = filename.to_s
    query = {
      expires: expires,
      sig: object_signature(repository, object_path, filename, expires)
    }
    query[:filename] = filename if filename.present?

    "#{download_endpoint}/#{repository}/#{escape_object_path(object_path)}?#{URI.encode_www_form(query)}"
  end

  def item_signature(slug, noid, file_type, canvas_noids, expires)
    payload = ['v2', slug, noid, file_type.upcase, canvas_noids.join("\n"), expires].join("\n")
    hmac(payload)
  end

  def object_signature(repository, object_path, filename, expires)
    payload = ['v1', repository, object_path, filename, expires].join("\n")
    hmac(payload)
  end

  def hmac(payload)
    return '' if download_token_secret.blank?

    OpenSSL::HMAC.hexdigest('SHA256', download_token_secret, payload)
  end

  def token_expires
    Time.now.to_i + token_ttl
  end

  def token_ttl
    raw_ttl = Rails.configuration.x.download_token_ttl
    raw_ttl = ENV.fetch('DOWNLOAD_TOKEN_TTL', '1800') unless raw_ttl.is_a?(Numeric) || raw_ttl.is_a?(String)
    ttl = raw_ttl.to_i
    ttl = MAX_TOKEN_TTL if ttl <= 0 || ttl > MAX_TOKEN_TTL
    ttl
  end

  def download_token_secret
    secret = Rails.configuration.x.download_token_secret
    secret = ENV.fetch('DOWNLOAD_TOKEN_SECRET', '') unless secret.is_a?(String)
    secret.to_s
  end

  def download_endpoint
    endpoint = Rails.configuration.x.download_api_endpoint
    endpoint = ENV.fetch('DOWNLOAD_API_ENDPOINT', 'https://beta-download.canadiana.ca/download') unless endpoint.is_a?(String)
    endpoint = 'https://beta-download.canadiana.ca/download' if endpoint.blank?
    endpoint = endpoint.sub(%r{/\z}, '')
    endpoint.end_with?('/download') ? endpoint : "#{endpoint}/download"
  end

  def escape_object_path(object_path)
    object_path.split('/').map { |segment| URI.encode_www_form_component(segment).gsub('+', '%20') }.join('/')
  end

  def image_download_uri(canvas_noid, slug, page_num)
    base = Rails.configuration.x.iiif_image_base.to_s.sub(%r{/+\z}, '')
    return '' if base.blank?

    image_uri = "#{base}/#{escape_iiif_identifier(canvas_noid)}/full/max/0/default.jpg"
    disposition = %(attachment; filename="#{safe_filename("#{slug}.#{page_num}.jpg")}")

    "#{image_uri}?#{URI.encode_www_form('response-content-disposition' => disposition)}"
  end

  def escape_iiif_identifier(identifier)
    URI.encode_www_form_component(identifier).gsub('+', '%20')
  end

  def safe_filename(filename)
    filename.to_s.gsub(%r{[\\/:*?"<>|]+}, '_')
  end
end
