class MembersComponent < ViewComponent::Base
  require 'zlib'

  LOGO_WORDMARKS = {
    'University of Victoria' => 'UVIC',
    'University of Ottawa' => 'uOttawa',
    'Universite du Quebec a Rimouski' => 'UQAR',
    'Universite du Quebec a Trois-Rivieres' => 'UQTR',
    'Universite du Quebec a Montreal' => 'UQAM',
    'Universite du Quebec a Chicoutimi' => 'UQAC',
    'Universite du Quebec en Abitibi-Temiscamingue' => 'UQAT',
    'Universite du Quebec en Outaouais' => 'UQO',
    'Universite de Montreal' => 'Universite de Montreal',
    'Universite Laval' => 'Universite Laval',
    'Universite de Sherbrooke' => 'Universite de Sherbrooke',
    'Universite de Moncton' => 'Universite de Moncton',
    'Universite Sainte-Anne' => 'Universite Sainte-Anne',
    'Bibliotheque et Archives nationales du Quebec' => 'BAnQ',
    'University of Prince Edward Island' => 'University of Prince Edward Island',
    'University of Northern British Columbia' => 'UNBC',
    'University of Lethbridge' => 'University of Lethbridge',
    'University of Guelph' => 'University of Guelph',
    'Nipissing University' => 'Nipissing University',
    'Ontario Tech University' => 'Ontario Tech University',
    'Vancouver Island University' => 'VIU',
    'Ecole Polytechnique de Montreal' => 'Polytechnique Montreal',
    "Bishop's University" => "Bishop's University"
  }.freeze

  STOP_WORDS = %w[of and the de du des et la le les d l a].freeze

  def initialize
    data = YAML.load_file(Rails.root.join('config', 'members.yml'))
    @institutional = Array(data['institutional'])
    @associate = Array(data['associate'])
    @provinces = (
      (@institutional + @associate).map { |m| m['province'] }.compact.uniq.sort
    )

    @institutional_rows = build_rows(@institutional)
    @associate_rows = build_rows(@associate)
  end

  def row_duration(index)
    [92, 104, 96, 108][index % 4]
  end

  def row_reverse?(index)
    index.odd?
  end

  def logo_text(name)
    normalized = normalize_name(name)
    return LOGO_WORDMARKS[normalized] if LOGO_WORDMARKS.key?(normalized)

    tokens = normalized.gsub(/[^[:alnum:]\s]/, ' ').split
    initials = tokens
      .reject { |token| STOP_WORDS.include?(token.downcase) }
      .map { |token| token[0] }
      .join
      .upcase

    return initials if initials.length.between?(2, 6)
    return normalized if normalized.length <= 24

    normalized[0, 24]
  end

  def logo_style(name)
    index = Zlib.crc32(name.to_s) % 4
    "logo-style-#{index + 1}"
  end

  def search_key(name)
    normalize_name(name).downcase
  end

  private

  def build_rows(items)
    shuffled = items.shuffle
    rows = Array.new(4) { [] }
    shuffled.each_with_index { |member, idx| rows[idx % 4] << member }
    rows
  end

  def normalize_name(name)
    name.to_s.unicode_normalize(:nfkd)
        .encode('ASCII', replace: '', undef: :replace, invalid: :replace)
        .squeeze(' ')
        .strip
  end
end
