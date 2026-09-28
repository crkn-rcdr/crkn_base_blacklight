class CollectionItemsComponent < ViewComponent::Base
  def initialize(documentId:, page: 1, per_page: 12)
    @documentId = documentId
    @page = page.to_i
    @per_page = per_page.to_i

    solr_url = ENV.fetch("SOLR_URL")
    rsolr = RSolr.connect url: solr_url

    start = (@page - 1) * @per_page

    @response_data = rsolr.get 'select', params: {
      q: '*:*',
      fq: [
        %(serial_key:"#{RSolr.solr_escape(@documentId)}"),
        'is_issue:"Yes"'
      ],
      start: start,
      rows: @per_page,
      sort: 'id asc'
    }

    @collection_items = @response_data['response']['docs']
    @total_items = @response_data['response']['numFound']
    @total_pages = (@total_items.to_f / @per_page).ceil
  end
end
