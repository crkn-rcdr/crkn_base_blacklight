require 'cgi'

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
    @matching_pages ||= fetch_matching_pages
  end

  private

  def searchable_ark?
    path = ark_path
    return false if path.blank?
    return false if path.start_with?('69429/s')
    true
  end

  def fetch_matching_pages
    clean_path = ark_path.sub(%r{\A/+}, '')
    return [] if clean_path.blank? || @term.blank?
    
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
    docs.filter_map { |d| d['canvas_index']&.to_i }.select(&:positive?).uniq.sort
  rescue => e
    Rails.logger.warn("PageSearchComponent query error for #{ark_path}: #{e.message}") if defined?(Rails)
    []
  end
end
