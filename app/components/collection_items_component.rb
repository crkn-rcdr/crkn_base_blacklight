class CollectionItemsComponent < ViewComponent::Base
  def initialize(documentId:, page: 1, per_page: 12)
    @documentId = documentId
    @page = page.to_i
    @per_page = per_page.to_i

    solr_url = ENV.fetch("SOLR_URL")
    rsolr = RSolr.connect url: solr_url

    # Query all matching issue IDs for this serial parent
    id_response = rsolr.get 'select', params: {
      q: '*:*',
      fq: [
        %(serial_key:"#{RSolr.solr_escape(@documentId)}"),
        'is_issue:"Yes"'
      ],
      fl: 'id',
      rows: 10_000
    }

    all_docs = id_response.dig('response', 'docs') || []
    @total_items = id_response.dig('response', 'numFound') || 0
    @total_pages = (@total_items.to_f / @per_page).ceil

    # Naturally sort IDs (e.g. oocihm.8_05016_1, _2, ..., _10, _100)
    sorted_ids = all_docs.map { |d| d['id'] }.compact.sort_by { |id| natural_sort_key(id) }

    start = (@page - 1) * @per_page
    page_ids = sorted_ids.slice(start, @per_page) || []

    if page_ids.empty?
      @collection_items = []
    else
      escaped_ids = page_ids.map { |id| %("#{RSolr.solr_escape(id)}") }.join(' OR ')
      page_response = rsolr.get 'select', params: {
        q: '*:*',
        fq: [
          "id:(#{escaped_ids})"
        ],
        fl: 'id,ark,is_issue,subtitle_tsim,pub_date_si,collection_tsim',
        rows: @per_page
      }

      docs_by_id = (page_response.dig('response', 'docs') || []).each_with_object({}) do |doc, map|
        map[doc['id']] = doc
      end
      @collection_items = page_ids.map { |id| docs_by_id[id] }.compact
    end
  end

  private

  def natural_sort_key(str)
    str.to_s.split(/(\d+)/).map do |chunk|
      next if chunk.empty?
      chunk =~ /^\d+$/ ? [0, chunk.to_i] : [1, chunk.downcase]
    end.compact
  end
end
