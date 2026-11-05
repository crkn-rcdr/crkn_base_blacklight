require 'cgi'

class CurrentPageSearch < ActiveSupport::CurrentAttributes
  attribute :cache
end

class PageSearchComponent < ViewComponent::Base
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

  private

  def prefetch_cache
    CurrentPageSearch.cache ||= {}
    CurrentPageSearch.cache[@term] ||= {}
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

    paths_by_doc = {}
    docs_on_page.each do |doc|
      raw_ark = (doc.try(:_source)&.dig('ark') || (doc['ark'] rescue nil) || (doc[:ark] rescue nil))
      next if raw_ark.blank?

      path = CGI.unescape(raw_ark.to_s).sub(%r{^https?://n2t\.net/ark:/}i, '').sub(%r{^ark:/}i, '').sub(%r{\A/+}, '')
      next if path.blank? || path.start_with?('69429/s')

      paths_by_doc[path] = []
      prefetch_cache[path] = []
    end

    return if paths_by_doc.empty?

    base_uri = Blacklight.default_index.connection.uri.to_s rescue nil
    return if base_uri.blank?

    cs_url = base_uri.sub('blacklight_marc', 'content_search')
    rsolr = RSolr.connect(url: cs_url)

    id_clauses = paths_by_doc.keys.map { |p| "id:#{RSolr.solr_escape(p)}*" }.join(' OR ')
    solr_term = RSolr.solr_escape(@term)

    res = rsolr.get('select', params: {
      q: "(#{id_clauses}) AND ocrtext:#{solr_term}",
      fl: 'id,canvas_index',
      rows: 500
    })

    docs = res.dig('response', 'docs') || []
    sorted_paths = paths_by_doc.keys.sort_by { |p| -p.length }

    docs.each do |d|
      id = d['id'].to_s
      canvas_index = d['canvas_index']&.to_i
      next unless canvas_index && canvas_index.positive?

      matched_path = sorted_paths.find { |p| id.start_with?(p) }
      if matched_path
        prefetch_cache[matched_path] << canvas_index
      end
    end

    paths_by_doc.each_key do |p|
      prefetch_cache[p] = prefetch_cache[p].uniq.sort
    end
  rescue => e
    Rails.logger.warn("PageSearchComponent batch prefetch error: #{e.message}") if defined?(Rails)
  end

  def fetch_single_matching_pages(clean_path)
    base_uri = Blacklight.default_index.connection.uri.to_s rescue nil
    return [] if base_uri.blank?

    cs_url = base_uri.sub('blacklight_marc', 'content_search')
    rsolr = RSolr.connect(url: cs_url)
    res = rsolr.get('select', params: {
      q: "id:#{clean_path}* AND ocrtext:#{RSolr.solr_escape(@term)}",
      fl: 'canvas_index',
      rows: 50
    })
    docs = res.dig('response', 'docs') || []
    res_pages = docs.filter_map { |d| d['canvas_index']&.to_i }.select(&:positive?).uniq.sort
    prefetch_cache[clean_path] = res_pages
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

