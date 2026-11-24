require 'cgi'
require 'digest'

class CurrentPageSearch < ActiveSupport::CurrentAttributes
  attribute :cache
end

class PageSearchComponent < ViewComponent::Base
  BATCH_MAX_ROWS = 150
  SINGLE_MAX_ROWS = 50
  CACHE_TTL = 10.minutes

  def initialize(docId:, arkUrl:, term:)
    @document_id = docId
    @ark_url = arkUrl.to_s
    @term = (term || '').to_s
  end

  def render?
    searchable_ark? && @term.present? && @term != '*:*' && matching_pages.any?
  end

  def ark_path
    return '' if @ark_url.blank?
    decoded = CGI.unescape(@ark_url)
    decoded.sub(%r{^https?://n2t\.net/ark:/}i, '').sub(%r{^ark:/}i, '')
  end

  def matching_pages
    @matching_pages ||= begin
      clean_path = ark_path.sub(%r{\A/+}, '')
      return [] if clean_path.blank? || @term.blank?

      cached = prefetch_cache[clean_path]
      if cached
        cached
      else
        batch_prefetch_page_documents!
        prefetch_cache[clean_path] || fetch_single_matching_pages(clean_path)
      end
    end
  end

  def page_link_url(page_num)
    query_params = if respond_to?(:helpers) && helpers.respond_to?(:request) && helpers.request&.query_parameters
                     helpers.request.query_parameters.to_h
                   elsif respond_to?(:params)
                     params.to_unsafe_h
                   else
                     {}
                   end.with_indifferent_access

    # Strip document/context params and search_id
    query_params.delete(:id)
    query_params.delete(:search_id)
    query_params.delete(:counter)
    query_params.delete(:commit)
    query_params.delete(:utf8)

    query_params[:pageNum] = page_num
    query_params[:q] ||= @term if @term.present?

    if respond_to?(:helpers) && helpers.respond_to?(:solr_document_path)
      helpers.solr_document_path(@document_id, query_params)
    else
      "/catalogue/#{ERB::Util.url_encode(@document_id)}?#{query_params.to_query}"
    end
  end

  private

  def prefetch_cache
    CurrentPageSearch.cache ||= {}
    CurrentPageSearch.cache[@term] ||= {}
  end

  def rails_cache_key(clean_path)
    term_digest = Digest::SHA256.hexdigest(@term.strip.downcase)[0, 16]
    "page_search:v2:#{term_digest}:#{clean_path}"
  end

  def normalized_query_term
    q = @term.to_s.strip
    q.include?('|') ? q.gsub(/\s*\|\s*/, ' OR ') : q
  end

  def content_search_params(fq:, fl:, rows:)
    q = normalized_query_term
    params = {
      defType: 'edismax',
      qf: 'ocrtext ocrtext_general ocrtext_en ocrtext_fr',
      qs: 0,
      hl: false,
      q: q,
      fq: fq,
      fl: fl,
      rows: rows
    }
    params[:mm] = 1 if q =~ /\bOR\b/
    params
  end

  def batch_prefetch_page_documents!
    return if CurrentPageSearch.cache&.dig(@term, :__batch_prefetched)
    prefetch_cache[:__batch_prefetched] = true

    ctrl = controller rescue nil
    ctrl ||= helpers.controller rescue nil
    return if ctrl.blank?

    docs_on_page = ctrl.instance_variable_get(:@document_list)
    docs_on_page ||= ctrl.instance_variable_get(:@documents)
    docs_on_page ||= ctrl.instance_variable_get(:@response)&.documents

    return if docs_on_page.blank?

    candidate_paths = []
    docs_on_page.each do |doc|
      raw_ark = (doc.try(:_source)&.dig('ark') || (doc['ark'] rescue nil) || (doc[:ark] rescue nil))
      next if raw_ark.blank?

      path = CGI.unescape(raw_ark.to_s).sub(%r{^https?://n2t\.net/ark:/}i, '').sub(%r{^ark:/}i, '').sub(%r{\A/+}, '')
      next if path.blank? || path.start_with?('69429/s')

      candidate_paths << path
      prefetch_cache[path] = []
    end

    candidate_paths.uniq!
    return if candidate_paths.empty?

    # Reuse per-(term, manifest) cached page lists across sort/page switches
    uncached_paths = candidate_paths
    if defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
      key_by_path = candidate_paths.index_with { |p| rails_cache_key(p) }
      cached_map = Rails.cache.read_multi(*key_by_path.values)
      uncached_paths = []
      key_by_path.each do |path, cache_key|
        if cached_map.key?(cache_key) && cached_map[cache_key].is_a?(Array)
          prefetch_cache[path] = cached_map[cache_key]
        else
          uncached_paths << path
        end
      end
    end

    return if uncached_paths.empty?

    base_uri = Blacklight.default_index.connection.uri.to_s rescue nil
    return if base_uri.blank?

    cs_url = base_uri.sub('blacklight_marc', 'content_search')
    rsolr = RSolr.connect(url: cs_url)

    # Use exact {!terms f=manifestid} filter (inverted index lookup, zero FieldCache)
    # and edismax with qs=0 (matching SearchBuilder) so quoted phrases and boolean OR
    # queries highlight only pages that actually match the user's query.
    res = rsolr.post('select', data: content_search_params(
      fq: "{!terms f=manifestid}#{uncached_paths.join(',')}",
      fl: 'id,canvas_index',
      rows: BATCH_MAX_ROWS
    ))

    docs = res.dig('response', 'docs') || []
    sorted_paths = uncached_paths.sort_by { |p| -p.length }

    docs.each do |d|
      id = d['id'].to_s
      canvas_index = d['canvas_index']&.to_i
      next unless canvas_index && canvas_index >= 0

      # Solr canvas_index is 0-based; UI/Mirador pageNum is 1-based (canvas_index + 1)
      page_num = canvas_index + 1

      matched_path = sorted_paths.find { |p| id.start_with?(p) }
      if matched_path
        prefetch_cache[matched_path] << page_num
      end
    end

    uncached_paths.each do |p|
      pages = prefetch_cache[p].uniq.sort
      prefetch_cache[p] = pages
      if defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
        Rails.cache.write(rails_cache_key(p), pages, expires_in: CACHE_TTL)
      end
    end
  rescue => e
    Rails.logger.warn("PageSearchComponent batch prefetch error: #{e.message}") if defined?(Rails)
  end

  def fetch_single_matching_pages(clean_path)
    if defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
      cached = Rails.cache.read(rails_cache_key(clean_path))
      if cached.is_a?(Array)
        prefetch_cache[clean_path] = cached
        return cached
      end
    end

    base_uri = Blacklight.default_index.connection.uri.to_s rescue nil
    return [] if base_uri.blank?

    cs_url = base_uri.sub('blacklight_marc', 'content_search')
    rsolr = RSolr.connect(url: cs_url)
    res = rsolr.post('select', data: content_search_params(
      fq: "{!terms f=manifestid}#{clean_path}",
      fl: 'canvas_index',
      rows: SINGLE_MAX_ROWS
    ))
    docs = res.dig('response', 'docs') || []
    # Solr canvas_index is 0-based; UI/Mirador pageNum is 1-based (canvas_index + 1)
    res_pages = docs.filter_map do |d|
      idx = d['canvas_index']&.to_i
      idx && idx >= 0 ? idx + 1 : nil
    end.uniq.sort
    prefetch_cache[clean_path] = res_pages
    if defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
      Rails.cache.write(rails_cache_key(clean_path), res_pages, expires_in: CACHE_TTL)
    end
    res_pages
  rescue => e
    Rails.logger.warn("PageSearchComponent query error for #{clean_path}: #{e.message}") if defined?(Rails)
    []
  end

  def searchable_ark?
    path = ark_path
    return false if path.blank?
    return false if path.start_with?('69429/s')
    true
  end
end
