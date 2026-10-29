class CollectionItemsComponent < ViewComponent::Base
  attr_reader :documentId, :page, :per_page, :date_from, :date_to,
              :total_items, :total_pages, :total_all_items, :collection_items,
              :available_years, :min_year, :max_year

  def initialize(documentId:, page: 1, per_page: 12, date_from: nil, date_to: nil)
    @documentId = documentId
    @page = [page.to_i, 1].max
    @per_page = [per_page.to_i, 1].max
    @date_from = date_from.presence&.to_s&.strip
    @date_to = date_to.presence&.to_s&.strip
    @available_years = []
    @min_year = nil
    @max_year = nil

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

    fq = [
      %(serial_key:"#{RSolr.solr_escape(@documentId)}"),
      'is_issue:"Yes"'
    ]

    # Date range filtering on pub_date_si
    if @date_from.present? || @date_to.present?
      clean_from = @date_from.present? ? @date_from.gsub(/[^0-9]/, '') : ''
      clean_to = @date_to.present? ? @date_to.gsub(/[^0-9]/, '') : ''

      clean_from = clean_from[0..3] if clean_from.length > 4
      clean_to = clean_to[0..3] if clean_to.length > 4

      # Swap if inverted
      if clean_from.present? && clean_to.present? && clean_from.to_i > clean_to.to_i
        clean_from, clean_to = clean_to, clean_from
        @date_from, @date_to = clean_from, clean_to
      end

      from_solr = clean_from.present? ? clean_from : '*'
      to_solr = clean_to.present? ? clean_to : '*'

      if from_solr != '*' || to_solr != '*'
        fq << %({!tag=date_filter}pub_date_si:[#{from_solr} TO #{to_solr}])
      end
    end

    # Native Solr pagination & index-level sort: query issues + facets & stats on pub_date_si
    response = rsolr.get 'select', params: {
      q: '*:*',
      fq: fq,
      fl: 'id,ark,is_issue,subtitle_tsim,pub_date_si,collection_tsim',
      sort: 'issue_sort_s asc, pub_date_si asc, id asc',
      start: start,
      rows: @per_page,
      facet: true,
      'facet.field' => '{!ex=date_filter}pub_date_si',
      'facet.mincount' => 1,
      'facet.sort' => 'index',
      'facet.limit' => -1,
      stats: true,
      'stats.field' => '{!ex=date_filter}pub_date_si'
    }

    @total_items = response.dig('response', 'numFound') || 0
    @total_pages = (@total_items.to_f / @per_page).ceil
    @collection_items = response.dig('response', 'docs') || []

    # Extract stats min/max year
    stats_data = response.dig('stats', 'stats_fields', '{!ex=date_filter}pub_date_si') ||
                 response.dig('stats', 'stats_fields', 'pub_date_si')
    if stats_data
      @min_year = stats_data['min']&.to_i
      @max_year = stats_data['max']&.to_i
      @total_all_items = stats_data['count']&.to_i || @total_items
    else
      @total_all_items = @total_items
    end

    # Extract available years from facet (sorted ascending by year)
    facet_raw = response.dig('facet_counts', 'facet_fields', '{!ex=date_filter}pub_date_si') ||
                response.dig('facet_counts', 'facet_fields', 'pub_date_si') || []
    @available_years = facet_raw.each_slice(2).map do |val, count|
      [val.to_s, count.to_i]
    end.reject { |val, _| val.blank? || val.to_i <= 0 }
  rescue StandardError => e
    Rails.logger.error("CollectionItemsComponent error fetching issues for #{@documentId}: #{e.message}")
    @collection_items = []
    @total_items = 0
    @total_pages = 0
    @available_years = []
  end

  def filtered?
    @date_from.present? || @date_to.present?
  end
end
