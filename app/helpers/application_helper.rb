# See: https://github.com/pulibrary/orangelight/blob/main/app/helpers/application_helper.rb
require 'cgi'  # For URL escaping

module ApplicationHelper
  # Ensure document links carry current search query, language, and search session ID by default.
  # This overrides Blacklight's helper in the view context.
  def url_for_document(document, options = {})
    opts = options.symbolize_keys
    opts[:q] = params[:q] if params[:q].present? && !opts.key?(:q)
    opts[:lang] = params[:lang] if params[:lang].present? && !opts.key?(:lang)
    if respond_to?(:current_search_session) && current_search_session&.id.present? && !opts.key?(:search_id)
      opts[:search_id] = current_search_session.id
    elsif respond_to?(:search_session) && search_session['id'].present? && !opts.key?(:search_id)
      opts[:search_id] = search_session['id']
    end
    solr_document_path(document, opts)
  end

  # Constructs the URL to return to the catalog search results with all search filters,
  # facets, search fields, and pagination preserved from the active search session.
  def back_to_search_url
    query_params = if respond_to?(:current_search_session) && current_search_session.try(:query_params).present?
                     search_state.reset(current_search_session.query_params).to_hash
                   else
                     request.query_parameters.except('pageNum', 'id').to_h
                   end

    query_params = query_params.with_indifferent_access

    if respond_to?(:search_session) && search_session['counter']
      per_page = (search_session['per_page'] || blacklight_config.default_per_page).to_i
      counter = search_session['counter'].to_i

      query_params[:per_page] = per_page unless search_session['per_page'].to_i == blacklight_config.default_per_page
      query_params[:page] = ((counter - 1) / per_page) + 1
    end

    query_params.delete(:id)
    query_params.delete(:pageNum)
    query_params.delete(:utf8)
    query_params.delete(:commit)

    lang = current_ui_language_param
    query_params[:lang] ||= lang if lang.present?

    clean_params = query_params.except(:controller, :action, :only_path)
    if clean_params.except(:lang).empty? && clean_params[:q].blank?
      search_action_path(only_path: true, lang: query_params[:lang])
    else
      search_action_path(clean_params.merge(only_path: true))
    end
  end

  # Disable prev/next item pagination on item and serial display pages
  def item_page_entry_info
    nil
  end

  def link_to_previous_document(_doc = nil)
    nil
  end

  def link_to_next_document(_doc = nil)
    nil
  end

  def render_search_context(_opts = {})
    nil
  end

  # Blacklight's inclusive facets store OR values as one nested array.
  def render_search_to_page_title_filter(facet, values)
    facet_config = facet_configuration_for_field(facet)
    filter_label = facet_field_label(facet_config.key)
    values = values.flatten

    filter_value = if values.size < 3
                     values.map do |value|
                       label = facet_item_presenter(facet_config, value, facet).label
                       label = strip_tags(label) if label.html_safe?
                       label
                     end.to_sentence
                   else
                     t('blacklight.search.page_title.many_constraint_values', values: values.size)
                   end

    t('blacklight.search.page_title.constraint', label: filter_label, value: filter_value)
  end

  def render_icon(var)
    "<span title='#{var.parameterize}' class='icon icon-#{var.parameterize}' aria-hidden='true'></span>"
  end
  def format_render(var)
    "<span class='format-text'>#{var.parameterize}</span>"
  end
  def format_icon(args)
    format_str = args[:document][args[:field]].join(', ').to_s
    if format_str.include?('Serial')
      if args[:document][:id].include?('N')
        format_str = 'newspaper-issue'
      else
        format_str = 'journal-issue'
      end
    end
    icon = render_icon(format_str)
    formats = format_render(format_str)
    content_tag :ul do
      content_tag :li, " #{icon} #{formats} ".html_safe, class: 'blacklight-format', dir: 'ltr'
    end
  end
  def value_link(args)
    value_str = Array(args[:document][args[:field]]).join(', ')
    content_tag :a, "#{value_str}".html_safe, href: value_str, dir: 'ltr'
  end
  def format_identifier(args)
    value = args[:document].id.presence || Array(args[:document][args[:field]]).first
    content_tag :p, value.to_s, class: 'metadata-identifier', dir: 'ltr'
  end
  def format_rights_statement(args)
    values = rights_statement_labels(args[:document], args[:field])
    return ''.html_safe if values.blank?

    content_tag :div, safe_join(values.map { |value| rights_statement_badge(value) }), class: 'rights-statement-list'
  end

  def format_rights_statement_text(args)
    field = args[:field]
    values = Array(args[:document][field]).compact_blank
    values = Array(args[:document]['rights_stat_tsim']).compact_blank if values.blank? && field.to_s != 'rights_stat_tsim'
    values = Array(args[:document]['rights_statement_ssim_str']).compact_blank if values.blank?
    return ''.html_safe if values.blank?

    rendered_values = values.map do |value|
      escaped_value = ERB::Util.html_escape(value.to_s)
      escaped_value.gsub(%r{https?://[^\s<]+}) do |url|
        link_to(url, url, target: '_blank', rel: 'noopener')
      end.html_safe
    end

    content_tag :p, safe_join(rendered_values, ', '), dir: 'ltr'
  end

  def format_result_chips(document)
    values = Array(document['format']).compact_blank
    return ''.html_safe if values.blank?

    safe_join(values.map do |value|
      format_key = value.to_s.parameterize
      format_key = if value.to_s.include?('Serial')
                     document[:id].to_s.include?('N') ? 'newspaper' : 'journal'
                   else
                     format_key
                   end
      normalized_key = {
        'ebook' => 'book',
        'software' => 'book',
        'newspaper-issue' => 'newspaper',
        'journal-issue' => 'journal'
      }.fetch(format_key, format_key)

      format_label = I18n.t("blacklight.metadata.resource_type.values.#{normalized_key.underscore}", default: normalized_key.tr('-', ' ').titleize)

      tag.span(class: 'result-chip result-chip--format') do
        tag.span(format_label, class: 'result-chip__label')
      end
    end, ' ')
  end

  def result_rights_statement_chips(document)
    values = Array(document['rights_statement_ssim_str']).compact_blank
    values = rights_statement_labels(document, 'rights_stat_tsim') if values.blank?
    values = rights_statement_labels(document, 'rights_statement_ssim') if values.blank?
    safe_join(values.map { |value| rights_statement_badge(value) }, ' ')
  end

  def render_rights_statement_facet_label(value)
    RightsStatementLabeler.localized_label_for(value)
  end

  def rights_statement_present?(_field_config, document)
    document['rights_statement_ssim_str'].present? ||
      rights_statement_labels(document, 'rights_stat_tsim').present? ||
      rights_statement_labels(document, 'rights_statement_ssim').present?
  end

  def format_text(args)
    args[:document][args[:field]].map! do |item|
      item.gsub(/https?:\/\/\S+/) do |url|
        "<a href=\"#{url}\" target=\"_blank\">#{url}</a>"
      end
    end
    value_str = Array(args[:document][args[:field]]).join('<br/>')
    value_str.sub!(/<br\/>$/, '')
    content_tag :p, "#{value_str}".html_safe, dir: 'ltr'
  end

  def format_facet(args)
    field_name = args[:field].to_s
    facet_param = facet_param_name(field_name)

    values = Array(args[:document][args[:field]])
    linked_values = values.map do |value|
      escaped_value = CGI.escape(value.to_s)
      "<a href=\"/catalogue?f%5B#{facet_param}%5D%5B%5D=#{escaped_value}&q=&search_field=all_fields\">#{value}</a>"
    end

    value_str = linked_values.join('<br/>')
    value_str.sub!(/<br\/>$/, '')
    content_tag :p, value_str.html_safe, dir: 'ltr'
  end

  def format_resource_type_label(value)
    key = case value.to_s
          when /Book|Monograph|eBook|Software/i then 'book'
          when /Journal/i then 'journal'
          when /Newspaper/i then 'newspaper'
          when /Musical|Score/i then 'musical_score'
          when /Map/i then 'map'
          else value.to_s.parameterize.underscore
          end
    I18n.t("blacklight.metadata.resource_type.values.#{key}", default: value.to_s.titleize)
  end

  def rights_statement_badge(value)
    raw_label = RightsStatementLabeler.labels_for_text(value.to_s).first || value.to_s
    localized_label = RightsStatementLabeler.localized_label_for(raw_label)
    category = RightsStatementLabeler.category_for_label(raw_label)
    url = RightsStatementLabeler.canonical_url_for_label(raw_label)
    icon = rights_statement_icon(category)
    label_content = if url.present?
                      link_to(localized_label, url, target: '_blank', rel: 'noopener', class: 'rights-statement-badge__link')
                    else
                      tag.span(localized_label, class: 'rights-statement-badge__link')
                    end

    tag.span(
      safe_join([icon, label_content]),
      class: "rights-statement-badge rights-statement-badge--#{category}",
      dir: 'ltr'
    )
  end

  def rights_statement_labels(document, field)
    raw_values = Array(document[field]).compact_blank
    raw_values = Array(document['rights_stat_tsim']).compact_blank if raw_values.blank? && field.to_s != 'rights_stat_tsim'
    raw_values = Array(document['rights_statement_ssim_str']).compact_blank if raw_values.blank?

    raw_values.flat_map do |value|
      val_str = value.to_s.strip
      if RightsStatementLabeler.statement_for_label(val_str)
        val_str
      else
        labels = RightsStatementLabeler.labels_for_text(val_str)
        labels.presence || [val_str]
      end
    end.uniq
  end

  def rights_statement_icon(category)
    tag.span('', class: "rights-statement-badge__icon rights-statement-badge__icon--#{category}", aria: { hidden: true })
  end
  def format_date(args)
    Time.parse(args[:document][args[:field]].to_s).strftime("%Y-%m-%d")
  rescue
    args[:document][args[:field]].to_s # Fallback to original if parsing fails
  end

  # Build language-aware collection breadcrumbs from hierarchy facet values.
  def collection_breadcrumb_paths(document)
    field, values = collection_hierarchy_values(document)
    return [] if values.blank?

    paths = values.filter_map do |value|
      parts = value.to_s.split('/').map { |part| part.to_s.strip }.reject(&:blank?)
      next if parts.empty?

      parts.each_index.map do |idx|
        { label: parts[idx], value: parts[0..idx].join('/'), field: field }
      end
    end

    return [] if paths.blank?

    # Drop any path that is a strict prefix of a longer one so we only show the
    # deepest breadcrumb for each hierarchy branch.
    filtered = paths.reject do |path|
      paths.any? do |other|
        next if path.equal?(other) || path == other
        path.length < other.length &&
          path.each_index.all? { |idx| other[idx].present? && other[idx][:value] == path[idx][:value] }
      end
    end

    filtered.presence || paths
  end

  def collection_breadcrumb_url(facet_value, field = nil)
    facet_field = field || collection_hierarchy_facet_field
    params_hash = { "f[#{facet_field}][]" => facet_value }
    lang = current_ui_language_param
    params_hash[:lang] = lang if lang.present?
    search_action_path(params_hash)
  end

  def current_ui_language_param
    if respond_to?(:content_lang)
      val = content_lang
      return val if val.present?
    end
    return params[:lang] if params[:lang].present?

    I18n.locale.to_s
  end

  def current_ui_language_code
    current_ui_language_param.to_s.start_with?('fr') ? 'fr' : 'en'
  end

  def collection_hierarchy_facet_field
    current_ui_language_code == 'fr' ? 'collectionfr_path' : 'collectionen_path'
  end

  def collection_hierarchy_values(document)
    primary_field = collection_hierarchy_facet_field
    values = Array(document[primary_field]).compact
    return [primary_field, values] if values.present?

    fallback_field = primary_field == 'collectionen_path' ? 'collectionfr_path' : 'collectionen_path'
    [fallback_field, Array(document[fallback_field]).compact]
  end

  def facet_param_name(field_name)
    return field_name if field_name.end_with?('_str')

    case field_name
    when 'materials_ssim_en', 'materials_ssim_fr',
         'collectionen_path', 'collectionfr_path'
      field_name
    else
      "#{field_name}_str"
    end
  end

  # Returns randomized card metadata for the Canadiana/Heritage intro stack.
  # URL format: https://www.canadiana.ca/view/oocihm.<id>/<page>
  # Parsing rule: the final numeric segment after the last dot is page,
  # everything before that final dot is the identifier.
  def canadiana_stack_cards(count = 12, collection: :canadiana)
    count = count.to_i
    count = 12 if count <= 0
    collection_key = canadiana_stack_collection_key(collection)
    view_host = canadiana_stack_view_host(collection_key)

    cards = canadiana_stack_asset_names(collection_key)
      .map { |image| canadiana_stack_card_from_image(image) }
      .compact

    if cards.empty?
      cards = canadiana_stack_fallback_images(collection_key)
        .map { |image| canadiana_stack_card_from_image(image) }
        .compact
    end

    return [] if cards.empty?

    cards = cards.map { |card| canadiana_stack_card_with_host(card, view_host) }
    cards = cards.shuffle
    return cards.take(count) if cards.length >= count

    # Pad deterministically when fewer cards exist than requested.
    padded = cards.dup
    while padded.length < count
      padded << cards[padded.length % cards.length]
    end
    padded
  end

  # Backward-compatible helper where only image names are needed.
  def canadiana_stack_image_names(count = 3, collection: :canadiana)
    canadiana_stack_cards(count, collection: collection).map { |card| card[:image] }
  end

  private

  def canadiana_stack_asset_names(collection = :canadiana)
    image_root = Rails.root.join('app/assets/images')
    collection_key = canadiana_stack_collection_key(collection)
    collection_root = image_root.join('backgrounds', collection_key)
    return [] unless Dir.exist?(collection_root)

    allowed_exts = %w[.jpg .jpeg .png .webp]

    Dir.glob(collection_root.join('**/*').to_s)
      .select { |path| File.file?(path) }
      .select do |path|
        ext = File.extname(path).downcase
        allowed_exts.include?(ext)
      end
      .map { |path| path.delete_prefix("#{image_root.to_s}/").delete_prefix("#{image_root.to_s}\\") }
      .sort
      .uniq
  end

  def canadiana_stack_collection_key(collection)
    key = collection.to_s.strip.downcase
    return 'heritage' if key == 'heritage'

    'canadiana'
  end

  def canadiana_stack_fallback_images(collection)
    case canadiana_stack_collection_key(collection)
    when 'heritage'
      %w[
        backgrounds/heritage/oocihm.lac_reel_c1845.9.jpg
        backgrounds/heritage/oocihm.lac_reel_c13421.54.jpg
        backgrounds/heritage/oocihm.lac_reel_h1228.150.jpg
      ]
    else
      %w[
        backgrounds/canadiana/oocihm.8_06251_308.20.jpg
        backgrounds/canadiana/oocihm.8_04191_542.2.jpg
        backgrounds/canadiana/oocihm.08567.22.jpg
      ]
    end
  end

  def canadiana_stack_view_host(collection)
    return 'https://heritage.canadiana.ca' if canadiana_stack_collection_key(collection) == 'heritage'

    'https://www.canadiana.ca'
  end

  def canadiana_stack_card_with_host(card, view_host)
    id = card[:id]
    page = card[:page]
    prefix = card[:prefix].presence || 'oocihm'
    return card if id.blank? || page.blank?

    id_path = "#{prefix}.#{id}/#{page}"
    url = "#{view_host}/view/#{id_path}"
    label = canadiana_stack_custom_label_for(url).presence || id_path

    card.merge(
      label: label,
      url: url
    )
  end

  def canadiana_stack_card_from_image(image)
    stem = File.basename(image.to_s, File.extname(image.to_s))
    match = stem.match(/\A(oocihm|oocigm)\.(.+)\z/i)
    return nil unless match

    prefix = match[1].downcase
    remainder = match[2]
    id, page = canadiana_stack_extract_id_and_page(remainder)
    return nil if id.blank? || page.blank?

    {
      image: image,
      prefix: prefix,
      id: id,
      page: page,
      label: "#{prefix}.#{id}/#{page}",
      url: "https://www.canadiana.ca/view/#{prefix}.#{id}/#{page}"
    }
  end

  def canadiana_stack_extract_id_and_page(remainder)
    text = remainder.to_s
      .strip
      .tr('@', '.')
      .gsub(/\s+/, '')
      .gsub(/[^0-9A-Za-z_.-]/, '')
      .gsub(/\.+/, '.')
      .sub(/\A\./, '')
      .sub(/\.\z/, '')

    if text.include?('.')
      id_raw, _separator, page_raw = text.rpartition('.')
      id_raw = text if id_raw.blank?
    else
      id_raw = text
      page_raw = '1'
    end

    id = id_raw.to_s.gsub(/[^0-9A-Za-z_-]/, '')
    page = page_raw.to_s.gsub(/[^0-9A-Za-z-]/, '')
    page = '1' if page.blank?

    [id, page]
  end

  def canadiana_stack_custom_label_for(url)
    canadiana_stack_custom_label_lookup[canadiana_stack_normalize_url(url)]
  end

  def canadiana_stack_custom_label_lookup
    @canadiana_stack_custom_label_lookup ||= begin
      path = Rails.root.join('config', 'home_image_labels.csv')
      lookup = {}
      if File.exist?(path)
        require 'csv'
        CSV.foreach(path, headers: false, encoding: 'bom|utf-8') do |row|
          label = row[0].to_s.strip
          link = canadiana_stack_normalize_url(row[1])
          next if label.blank? || link.blank?

          lookup[link] = label
        end
      end
      lookup
    rescue StandardError
      {}
    end
  end

  def canadiana_stack_normalize_url(url)
    value = url.to_s.strip
    return '' if value.blank?

    value.sub(%r{/\z}, '')
  end
end


