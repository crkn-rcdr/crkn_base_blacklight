class CollectionItemsComponent < ViewComponent::Base
  attr_reader :documentId, :page, :per_page, :total_items, :total_pages, :collection_items

  def initialize(documentId:, page: 1, per_page: 12)
    @documentId = documentId
    @page = [page.to_i, 1].max
    @per_page = [per_page.to_i, 1].max

    if @documentId.blank?
      @collection_items = []
      @total_items = 0
      @total_pages = 0
      return
    end

    solr_url = ENV.fetch("SOLR_URL", nil)
    unless solr_url.present?
      @collection_items = []
      @total_items = 0
      @total_pages = 0
      return
    end

    rsolr = RSolr.connect url: solr_url
    start = (@page - 1) * @per_page

    # Native Solr pagination & index-level sort: single query for issues
    response = rsolr.get 'select', params: {
      q: '*:*',
      fq: [
        %(serial_key:"#{RSolr.solr_escape(@documentId)}"),
        'is_issue:"Yes"'
      ],
      fl: 'id,ark,is_issue,subtitle_tsim,pub_date_si,collection_tsim',
      sort: 'issue_sort_s asc, pub_date_si asc, id asc',
      start: start,
      rows: @per_page
    }

    @total_items = response.dig('response', 'numFound') || 0
    @total_pages = (@total_items.to_f / @per_page).ceil
    @collection_items = response.dig('response', 'docs') || []
  rescue StandardError => e
    Rails.logger.error("CollectionItemsComponent error fetching issues for #{@documentId}: #{e.message}")
    @collection_items = []
    @total_items = 0
    @total_pages = 0
  end
end
