# See: https://github.com/pulibrary/orangelight/blob/main/app/helpers/application_helper.rb
require 'cgi'  # For URL escaping

module ApplicationHelper
  # Ensure document links carry current search query and language by default.
  # This overrides Blacklight's helper in the view context.
  def url_for_document(document, options = {})
    opts = options.symbolize_keys
    opts[:q] = params[:q] if params[:q].present? && !opts.key?(:q)
    opts[:lang] = params[:lang] if params[:lang].present? && !opts.key?(:lang)
    solr_document_path(document, opts)
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
      "<a href=\"/catalog?f%5B#{facet_param}%5D%5B%5D=#{escaped_value}&q=&search_field=all_fields\">#{value}</a>"
    end

    value_str = linked_values.join('<br/>')
    value_str.sub!(/<br\/>$/, '')
    content_tag :p, value_str.html_safe, dir: 'ltr'
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

  # Returns randomized card metadata for the Canadiana intro stack.
  # URL format: https://www.canadiana.ca/view/oocihm.<id>/<page>
  # Parsing rule: the final numeric segment after the last dot is page,
  # everything before that final dot is the identifier.
  def canadiana_stack_cards(count = 12)
    count = count.to_i
    count = 12 if count <= 0

    cards = canadiana_stack_asset_names
      .map { |image| canadiana_stack_card_from_image(image) }
      .compact

    if cards.empty?
      cards = [
        {
          image: 'oocihm.12020.87.png',
          prefix: 'oocihm',
          id: '12020',
          page: '87',
          label: 'oocihm.12020/87',
          url: 'https://www.canadiana.ca/view/oocihm.12020/87'
        },
        {
          image: 'oocihm.8_06251_308@20.jpg',
          prefix: 'oocihm',
          id: '8_06251_308',
          page: '20',
          label: 'oocihm.8_06251_308/20',
          url: 'https://www.canadiana.ca/view/oocihm.8_06251_308/20'
        },
        {
          image: 'oocihm.08567.22.jpg',
          prefix: 'oocihm',
          id: '08567',
          page: '22',
          label: 'oocihm.08567/22',
          url: 'https://www.canadiana.ca/view/oocihm.08567/22'
        }
      ]
    end

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
  def canadiana_stack_image_names(count = 3)
    canadiana_stack_cards(count).map { |card| card[:image] }
  end

  private

  def canadiana_stack_asset_names
    image_root = Rails.root.join('app/assets/images')
    allowed_exts = %w[.jpg .jpeg .png .webp]

    Dir.glob(image_root.join('**/*').to_s)
      .select { |path| File.file?(path) }
      .select do |path|
        stem = File.basename(path, File.extname(path)).downcase
        ext = File.extname(path).downcase
        stem.start_with?('oocihm', 'oocigm') && allowed_exts.include?(ext)
      end
      .map { |path| path.delete_prefix("#{image_root.to_s}/").delete_prefix("#{image_root.to_s}\\") }
      .uniq
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
      label: "oocihm.#{id}/#{page}",
      url: "https://www.canadiana.ca/view/oocihm.#{id}/#{page}"
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
end


