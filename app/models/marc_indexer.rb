# frozen_string_literal: true
require 'time'
require_relative '../../lib/rights_statement_labeler'
$:.unshift './config'

class MarcIndexer < Blacklight::Marc::Indexer
  # this mixin defines lambda factory method get_format for legacy marc formats
  include Blacklight::Marc::Indexer::Formats

  HIER_DELIM = '|' # used by blacklight-hierarchy for splitting

  def initialize
    super

    settings do
      # type may be 'binary', 'xml', or 'json'
      provide "marc_source.type", "binary"
      # set this to be non-negative if threshold should be enforced
      provide 'solr_writer.max_skipped', -1
    end

    # https://github.com/ruby-marc/ruby-marc
    # https://github.com/traject/traject/blob/5d720e2ba0a277cf7af455763f520cd6a2d956c7/README.md?plain=1#L279
    to_field "id", extract_marc("001"), trim, first_only

    # 901 = "Is issue"  => Yes; otherwise (missing/different) => No
    to_field "is_issue" do |record, accumulator|
      v = record["901"]&.value&.strip
      accumulator.replace [ (v&.casecmp("Is issue")&.zero?) ? "Yes" : "No" ]
    end

    # --- serial_key: 902$b ---
    to_field "serial_key" do |record, acc|
      key = record["902"]&.subfields&.find { |sf| sf.code == 'b' }&.value&.strip
      if key && !key.empty?
        acc.replace [key]
      end
    end

    # --- serial_title: only for series/serials and individual issues ---
    to_field "serial_title", extract_marc('245a'), first_only do |rec, acc|
      v901 = rec["901"]&.value&.strip
      is_ser = v901&.casecmp("Is series")&.zero?
      is_iss = v901&.casecmp("Is issue")&.zero?
      has_serial_key = rec["902"]&.subfields&.any? { |sf| sf.code == 'b' && !sf.value.to_s.strip.empty? }

      if is_ser || is_iss || has_serial_key
        v = acc.first
        if v && v.include?(' : ')
          acc.replace([v.split(' : ', 2).first.strip])
        elsif v && v.include?(':')
          acc.replace([v.split(':', 2).first.strip])
        else
          acc.replace(v ? [v.strip] : [])
        end
      else
        acc.clear
      end
    end

    # --- is_serial: true for parent serials, not individual issues ---
    to_field "is_serial" do |record, accumulator|
      v = record["901"]&.value&.strip
      accumulator.replace [ (v&.casecmp("Is series")&.zero?) ? "Yes" : "No" ]
    end

    # --- resource_type_ssim: consolidated content/resource type facet ---
    to_field "resource_type_ssim" do |record, accumulator|
      accumulator.replace resource_type_facet_values(record)
    end

    to_field 'marc_ss', get_xml
    to_field "all_text_timv", extract_all_marc_values do |r, acc|
      acc.replace [acc.join(' ')] # turn it into a single string
    end

    to_field "language_ssim", marc_languages("008[35-37]:041a:041d:")
    to_field "format", get_format

    to_field 'material_type_ssm', extract_marc('300a'), trim_punctuation

    # Title fields
    # full title
    to_field 'full_title_tsim', extract_marc('245ab')
    to_field 'full_title_ssm', extract_marc('245ab', alternate_script: false), trim_punctuation
    to_field 'full_title_vern_ssm', extract_marc('245ab', alternate_script: :only), trim_punctuation

    # primary title
    to_field 'title_tsim', extract_marc('245a')
    to_field 'title_ssm', extract_marc('245a', alternate_script: false), trim_punctuation
    to_field 'title_vern_ssm', extract_marc('245a', alternate_script: :only), trim_punctuation

    # subtitle
    to_field 'subtitle_tsim', extract_marc('245b')
    to_field 'subtitle_ssm', extract_marc('245b', alternate_script: false), trim_punctuation
    to_field 'subtitle_vern_ssm', extract_marc('245b', alternate_script: :only), trim_punctuation

    # Other Titles
    to_field 'title_addl_tsim',
      extract_marc(%W{
        246abcdefgnp
        240abcdefgklmnopqrs
        242abnp
        243abcdefgklmnopqrs
        247abcdefgnp
        730abcdefgklmnopqrst
        740anp
        830adfghklmnoprstvwxy
      }.join(':'))
    to_field 'title_si', marc_sortable_title

    # Author fields
    to_field 'author_tsim', extract_marc("100abcegqu:110abcdegnu:111acdegjnqu:130#{ATOZ}:700abcegqu:710abcdegnu:711acdegjnqu:720#{ATOZ}")
    to_field 'author_ssm', extract_marc("100abcdq:110#{ATOZ}:111#{ATOZ}:130#{ATOZ}:700abcegqu:710abcdegnu:711acdegjnqu:720#{ATOZ}", alternate_script: false)
    to_field 'author_vern_ssm', extract_marc("100abcdq:110#{ATOZ}:111#{ATOZ}:130#{ATOZ}:700abcegqu:710abcdegnu:711acdegjnqu:720#{ATOZ}", alternate_script: :only)

    # JSTOR isn't an author. Try to not use it as one
    to_field 'author_si', marc_sortable_author

    # Subject fields
    to_field 'subject_tsim', extract_marc(%W(
      600#{ATOZ}
      610#{ATOZ}
      611#{ATOZ}
      630#{ATOZ}
      647#{ATOZ}
      648#{ATOZ}
      650#{ATOZ}
      651#{ATOZ}
      653#{ATOZ}
      654#{ATOZ}
      655#{ATOZ}
      656#{ATOZ}
      657#{ATOZ}
      658#{ATOZ}
      662#{ATOZ}
      688#{ATOZ}
    ).join(':'))

    to_field 'subject_ssim', extract_marc(%W(
      600#{ATOZ}
      610#{ATOZ}
      611#{ATOZ}
      630#{ATOZ}
      647#{ATOZ}
      648#{ATOZ}
      650#{ATOZ}
      651#{ATOZ}
      653#{ATOZ}
      654#{ATOZ}
      655#{ATOZ}
      656#{ATOZ}
      657#{ATOZ}
      658#{ATOZ}
      662#{ATOZ}
      688#{ATOZ}
    ).join(':')), trim_punctuation

    # Published statement
    to_field 'published_ssm', extract_marc('260abcefg:264abc', alternate_script: false), trim_punctuation
    to_field 'published_vern_ssm', extract_marc('260abcefg:264abc', alternate_script: :only), trim_punctuation

    # Published Dates (prioritizing original publication date over reproduction/digitization date)
    to_field 'pub_date_si' do |record, accumulator|
      year = extract_original_publication_year(record)
      accumulator << year if year
    end

    to_field 'pub_date_ssim' do |record, accumulator|
      year = extract_original_publication_year(record)
      accumulator << year if year
    end

    # ----------------------------
    # CRKN additions
    # ----------------------------

    # human-readable path for display/debug (language specific)
    to_field 'collectionen_path' do |rec, acc|
      collection_paths_by_language(rec)[:en].each do |segments|
        acc.concat(path_permutations(segments))
      end
      acc.uniq!
    end
    to_field 'collectionfr_path' do |rec, acc|
      collection_paths_by_language(rec)[:fr].each do |segments|
        acc.concat(path_permutations(segments))
      end
      acc.uniq!
    end

    to_field 'depositor_tsim', extract_marc('590a')

    # Document Source
    to_field 'doc_source_tsim', extract_marc('533abcdu')

    # Rights Statement
    to_field 'rights_stat_tsim', extract_marc('540abcdfgqu')
    to_field 'rights_statement_ssim' do |record, accumulator|
      accumulator.replace rights_statement_facet_values(record)
    end

    # Access Note
    to_field 'access_note_tsim', extract_marc('506abcdefgqu')

    # Original Version Note 534 - physical item desc
    to_field 'original_version_note_tsim', extract_marc('534abcefklmnoptxz')

    # Notes
    to_field 'notes_tsim', extract_marc(%W(
      500#{ATOZ}
      515#{ATOZ}
      546#{ATOZ}
    ).join(':'))

    # Source of Description
    to_field 'source_of_description_tsim', extract_marc(%W(588#{ATOZ}))

    # Series
    to_field 'title_series_tsim', extract_marc("440anpv:490av")

    to_field 'permalink_fulltext_ssm', extract_marc("856g")

    to_field 'date_added' do |record, accumulator|
      raw = record['998']&.value
      if raw
        # Parse MARC timestamp (e.g., "20240716103000.0005") and format only the date
        date = Time.strptime(raw[0..7], "%Y%m%d").utc.strftime("%Y-%m-%d")
        accumulator << date
      end
    end

    to_field 'date_edited' do |record, accumulator|
      raw = record['005']&.value
      if raw
        # Parse MARC timestamp (e.g., "20240716103000.0005") into ISO8601
        iso = Time.strptime(raw[0..13], "%Y%m%d%H%M%S").utc.iso8601
        accumulator << iso
      end
    end

    # URL Fields
    notfulltext = /abstract|description|sample text|table of contents/i
    to_field('url_fulltext_ssm') do |rec, acc|
      rec.fields('856').each do |f|
        case f.indicator2
        when '0'
          f.find_all{|sf| sf.code == 'u'}.each do |url|
            acc << url.value
          end
        when '2'
          # do nothing
        else
          z3 = [f['z'], f['3']].join(' ')
          unless notfulltext.match(z3)
            acc << f['u'] unless f['u'].nil?
          end
        end
      end
    end

    # Very similar to url_fulltext_display. Should DRY up.
    to_field 'url_suppl_ssm' do |rec, acc|
      rec.fields('856').each do |f|
        case f.indicator2
        when '2'
          f.find_all{|sf| sf.code == 'u'}.each do |url|
            acc << url.value
          end
        when '0'
          # do nothing
        else
          z3 = [f['z'], f['3']].join(' ')
          if notfulltext.match(z3)
            acc << f['u'] unless f['u'].nil?
          end
        end
      end
    end

    # Call Number fields
    to_field 'lc_callnum_ssm', extract_marc('050ab'), first_only

    first_letter = lambda {|rec, acc| acc.map!{|x| x[0]} }
    to_field 'lc_1letter_ssim', extract_marc('050ab'), first_only, first_letter, translation_map('callnumber_map')

    alpha_pat = /\A([A-Z]{1,3})\d.*\Z/
    alpha_only = lambda do |rec, acc|
      acc.map! do |x|
        (m = alpha_pat.match(x)) ? m[1] : nil
      end
      acc.compact! # eliminate nils
    end
    to_field 'lc_alpha_ssim', extract_marc('050a'), alpha_only, first_only

    to_field 'lc_b4cutter_ssim', extract_marc('050a'), first_only
  end

  private

  FRENCH_KEYWORDS = %w[serie series carte cartes annuelle annuelles periodique periodiques publication publications journaux].freeze
  ENGLISH_KEYWORDS = %w[serial serials map maps annual annuals periodical periodicals publication publications newspaper newspapers].freeze

  def extract_original_publication_year(record)
    # 1. Check 264$c with indicator 2 == '1' (Publication statement in RDA)
    record.fields('264').each do |field|
      next unless field.indicator2 == '1'
      field.find_all { |sf| sf.code == 'c' }.each do |sf|
        year = extract_year_from_string(sf.value)
        return year if year
      end
    end

    # 2. Check 260$c (Publication statement in AACR2)
    record.fields('260').each do |field|
      field.find_all { |sf| sf.code == 'c' }.each do |sf|
        year = extract_year_from_string(sf.value)
        return year if year
      end
    end

    # 3. Check any other 264$c (e.g. manufacture or production)
    record.fields('264').each do |field|
      field.find_all { |sf| sf.code == 'c' }.each do |sf|
        year = extract_year_from_string(sf.value)
        return year if year
      end
    end

    # 4. Check 008 control field (Date 2 for reprint/reproduction 'r')
    if (cf008 = record['008']&.value) && cf008.length >= 15
      type_of_date = cf008[6]
      date1 = cf008[7..10]
      date2 = cf008[11..14]

      if type_of_date == 'r'
        year2 = extract_year_from_string(date2)
        return year2 if year2
      end

      year1 = extract_year_from_string(date1)
      return year1 if year1 && type_of_date != 'r'
    end

    # 5. Check 534$c / 534$p (Original Version Note)
    record.fields('534').each do |field|
      field.find_all { |sf| %w[c p].include?(sf.code) }.each do |sf|
        year = extract_year_from_string(sf.value)
        return year if year
      end
    end

    # 6. Check 500$a general notes
    record.fields('500').each do |field|
      field.find_all { |sf| sf.code == 'a' }.each do |sf|
        year = extract_year_from_string(sf.value)
        return year if year
      end
    end

    # 7. Fallback to 008 Date 1 even if 'r' if no other date was found
    if (cf008 = record['008']&.value) && cf008.length >= 11
      year1 = extract_year_from_string(cf008[7..10])
      return year1 if year1
    end

    nil
  end

  def extract_year_from_string(str)
    return nil if str.blank?

    cleaned = str.to_s.gsub(/[\(\)\[\]\.\,\;\"\'\?]/, ' ')

    # Match exact 4-digit years like 1897 or 1900
    current_year = Time.now.year + 2
    if (match = cleaned.match(/\b(1\d{3}|20\d{2})\b/))
      year = match[1].to_i
      return year if year >= 1000 && year <= current_year
    end

    # Handle decade wildcards like 189u, 189-, 189? -> 1890
    if (match = cleaned.match(/\b(1\d{2}|20\d)[u\-\?]\b/i))
      return "#{match[1]}0".to_i
    end

    # Handle century wildcards like 18uu, 18--, 18?? -> 1800
    if (match = cleaned.match(/\b(1\d|20)[u\-\?]{2}\b/i))
      return "#{match[1]}00".to_i
    end

    nil
  end

  def materials_by_language(record)
    collection_paths_by_language(record).transform_values do |paths|
      paths.map(&:first).compact.uniq
    end
  end

  def rights_statement_facet_values(record)
    record.fields('540').flat_map do |field|
      field.find_all { |subfield| subfield.code == 'u' }
           .filter_map { |subfield| RightsStatementLabeler.label_for_url(subfield.value) }
    end.uniq
  end

  def resource_type_facet_values(record)
    formats = []
    get_format.call(record, formats, nil)
    formats.compact_blank!
    v901 = record['901']&.value&.strip
    is_serial_val = v901&.casecmp('Is series')&.zero? || v901&.casecmp('Is serial')&.zero?
    is_issue_val = v901&.casecmp('Is issue')&.zero? || record['902']&.subfields&.any? { |s| s.code == 'b' }
    record_id = (record['001']&.value || '').to_s

    is_newspaper = formats.any? { |f| f.to_s =~ /newspaper/i } || (record_id.include?('N') && (is_serial_val || is_issue_val || formats.any? { |f| f.to_s =~ /serial/i }))

    if is_newspaper
      ['Newspaper']
    elsif is_serial_val || is_issue_val || formats.any? { |f| f.to_s =~ /serial|journal/i }
      ['Journal']
    elsif formats.any? { |f| f.to_s =~ /score|musical/i }
      ['Musical Score']
    elsif formats.any? { |f| f.to_s =~ /map/i }
      ['Map']
    else
      ['Book']
    end
  end

  def collection_paths_by_language(record)
    result = { en: [], fr: [] }
    record.fields('999').each do |field|
      collection_segments_by_language(field).each do |lang, values|
        normalized = normalize_collection_segments(values)
        result[lang] << normalized unless normalized.empty?
      end
    end
    result.transform_values(&:uniq)
  end

  def collection_segments_by_language(field)
    segments = { en: [], fr: [] }
    field.each do |subfield|
      case subfield.code
      when 'e'
        segments[:en] << subfield.value
      when 'f'
        segments[:fr] << subfield.value
      end
    end
    segments
  end

  def normalize_collection_segments(values)
    Array(values).map { |value| normalize_collection_value(value) }.reject(&:blank?)
  end

  def normalize_collection_value(value)
    value.to_s.strip.sub(/\.\z/, '')
  end

  def path_permutations(segments)
    values = []
    current = nil
    segments.each do |segment|
      current = current ? "#{current}/#{segment}" : segment
      values << current
    end
    values
  end

  def detect_language_code(str)
    return nil if str.blank?

    downcased  = str.downcase
    normalized = strip_diacritics(downcased)

    return 'fr' unless downcased.ascii_only?
    return 'fr' if normalized.include?('en serie') || normalized.include?('publications en serie')
    return 'fr' if FRENCH_KEYWORDS.any? { |word| normalized.include?(word) }
    return 'eng' if ENGLISH_KEYWORDS.any? { |word| normalized.include?(word) }

    nil
  end

  def opposite_language_code(code)
    return nil if code.nil?
    code == 'fr' ? 'eng' : (code == 'eng' ? 'fr' : nil)
  end

  def strip_diacritics(str)
    return '' if str.blank?

    if str.respond_to?(:unicode_normalize)
      str.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')
    else
      ActiveSupport::Inflector.transliterate(str)
    end
  end
end

