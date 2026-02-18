class FeaturedItemsComponent < ViewComponent::Base
  attr_reader :page, :per_page, :total_items, :total_pages

  def initialize(items:, page: 1, per_page: 6)
    @items = normalize_items(items)
    @page = [page.to_i, 1].max
    @per_page = [per_page.to_i, 1].max
    @total_items = @items.length
    @total_pages = (@total_items.to_f / @per_page).ceil
    @page = [@page, [@total_pages, 1].max].min
    @items_by_id = @items.index_by { |item| item[:id] }
    @records = load_records_for_page
  end

  def records
    @records
  end

  def show_pagination?
    @total_items > @per_page
  end

  def prev_page
    [@page - 1, 1].max
  end

  def next_page
    [@page + 1, [@total_pages, 1].max].min
  end

  def title_for(record)
    item = @items_by_id[record['id']] || {}
    return item[:title] if item[:title].present?

    Array(record['subtitle_tsim']).first.presence ||
      Array(record['title_tsim']).first.presence ||
      record['id']
  end

  def description_for(record)
    item = @items_by_id[record['id']] || {}
    return item[:description] if item[:description].present?

    Array(record['collection_tsim']).last.to_s
  end

  def record_link(record)
    "/catalog/#{record['id']}?lang=#{I18n.locale}"
  end

  def viewer_id_for(record)
    "featured-osd-#{record['id'].to_s.gsub(/[^a-zA-Z0-9_-]/, '-')}"
  end

  def ark_identifier_for(record)
    Array(record['ark']).first.to_s.sub('https://n2t.net/ark:/', '')
  end

  private

  def load_records_for_page
    page_items = @items.slice((@page - 1) * @per_page, @per_page).to_a
    return [] if page_items.empty?

    docs_by_id = fetch_docs_by_id(page_items.map { |item| item[:id] })

    page_items.map do |item|
      record = docs_by_id[item[:id]] || { 'id' => item[:id] }
      ark_value = item[:ark].presence || Array(record['ark']).first.to_s.strip.presence
      record['ark'] = [ark_value] if ark_value.present?
      record
    end
  end

  def normalize_items(items)
    Array(items).filter_map do |item|
      if item.is_a?(Hash)
        id = (item[:id] || item['id']).to_s.strip
        next if id.blank?

        {
          id: id,
          ark: (item[:ark] || item['ark']).to_s.strip.presence,
          title: (item[:title] || item['title']).to_s.strip.presence,
          description: (item[:description] || item['description']).to_s.strip.presence
        }
      else
        id = item.to_s.strip
        next if id.blank?
        { id: id, ark: nil, title: nil, description: nil }
      end
    end
  end

  def fetch_docs_by_id(ids)
    ids.each_with_object({}) do |id, memo|
      begin
        response = solr_connection.get 'select', params: {
          q: '*:*',
          fq: "id:\"#{RSolr.solr_escape(id)}\"",
          rows: 1
        }
        doc = response.dig('response', 'docs').to_a.first
        memo[id] = doc if doc.present?
      rescue StandardError => e
        Rails.logger.warn("FeaturedItemsComponent record fetch failed for #{id}: #{e.class} #{e.message}")
      end
    end
  end

  def solr_connection
    @solr_connection ||= RSolr.connect url: 'http://public:hdwi389e8d!ds@4.229.225.26/solr/blacklight_marc_demo'
  end
end
