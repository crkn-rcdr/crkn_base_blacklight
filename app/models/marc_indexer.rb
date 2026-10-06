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

    # --- issue_sort_s: zero-padded ID sort key for natural sorting in Solr ---
    to_field "issue_sort_s" do |record, acc|
      v901 = record["901"]&.value&.strip
      is_iss = v901&.casecmp("Is issue")&.zero?
      has_serial_key = record["902"]&.subfields&.any? { |sf| sf.code == 'b' && !sf.value.to_s.strip.empty? }
      if is_iss || has_serial_key
        rec_id = record["001"]&.value&.strip
        if rec_id && !rec_id.empty?
          acc.replace [rec_id.gsub(/\d+/) { |n| n.rjust(10, '0') }]
        end
      end
    end

    # --- issue_seq_i: integer sequence number extracted from ID (e.g. trailing _123) ---
    to_field "issue_seq_i" do |record, acc|
      v901 = record["901"]&.value&.strip
      is_iss = v901&.casecmp("Is issue")&.zero?
      has_serial_key = record["902"]&.subfields&.any? { |sf| sf.code == 'b' && !sf.value.to_s.strip.empty? }
      if is_iss || has_serial_key
        rec_id = record["001"]&.value&.strip
        if rec_id && rec_id =~ /_(\d+)\z/
          acc.replace [$1.to_i]
        end
      end
    end

    # --- serial_title: only for series/serials and individual issues ---
    to_field "serial_title", extract_marc('245a'), first_only do |rec, acc|
      v901 = rec["901"]&.value&.strip
      is_ser = v901&.casecmp("Is series")&.zero?
      is_iss = v901&.casecmp("Is issue")&.zero?
      has_serial_key = rec["902"]&.subfields&.any? { |sf| sf.code == 'b' && !sf.value.to_s.strip.empty? }

      # Determined serial title metadata: 902$c (e.g. =902 $aIs part of$boocihm.N_00123$cChignecto Post)
      v902c = rec.fields('902').map { |f| f['c'] }.compact.map(&:strip).reject(&:empty?).first

      if is_ser || is_iss || has_serial_key || v902c
        if v902c
          acc.replace([v902c])
        else
          # Fallback to 245$a (stripping text after first colon) if 902$c doesn't exist
          v = acc.first
          if v && v.include?(' : ')
            acc.replace([v.split(' : ', 2).first.strip])
          elsif v && v.include?(':')
            acc.replace([v.split(':', 2).first.strip])
          else
            acc.replace(v ? [v.strip] : [])
          end
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
      years = extract_publication_years(record)
      accumulator.concat(years) if years.present?
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
    years = extract_publication_years(record)
    years.first
  end

  def extract_publication_years(record)
    # Check 008 multi-date range if present
    cf008_range = nil
    if (cf008 = record['008']&.value) && cf008.length >= 15
      type_of_date = cf008[6]
      date1 = cf008[7..10]
      date2 = cf008[11..14]

      if %w[m q d].include?(type_of_date)
        y1 = extract_year_from_string(date1)
        y2 = extract_year_from_string(date2)
        if y1 && y2 && y1 <= y2 && y1 >= 1000 && y2 <= (Time.now.year + 2)
          cf008_range = (y1..y2).to_a
        end
      end
    end

    # Helper to expand years with 008 range if applicable
    resolve_years = lambda do |years|
      if years.any?
        if years.size == 1 && cf008_range && cf008_range.include?(years.first)
          return cf008_range
        end
        return years
      end
      nil
    end

    # 1. Check 264$c with indicator 2 == '1' (Publication statement in RDA)
    record.fields('264').each do |field|
      next unless field.indicator2 == '1'
      field.find_all { |sf| sf.code == 'c' }.each do |sf|
        years = extract_years_from_string(sf.value)
        res = resolve_years.call(years)
        return res if res
      end
    end

    # 2. Check 260$c (Publication statement in AACR2)
    record.fields('260').each do |field|
      field.find_all { |sf| sf.code == 'c' }.each do |sf|
        years = extract_years_from_string(sf.value)
        res = resolve_years.call(years)
        return res if res
      end
    end

    # 3. Check any other 264$c (e.g. manufacture or production)
    record.fields('264').each do |field|
      field.find_all { |sf| sf.code == 'c' }.each do |sf|
        years = extract_years_from_string(sf.value)
        res = resolve_years.call(years)
        return res if res
      end
    end

    # 4. Check 008 control field (Date 2 for reprint/reproduction 'r', or multi-date 'm', 'q', 'd')
    if (cf008 = record['008']&.value) && cf008.length >= 15
      type_of_date = cf008[6]
      date1 = cf008[7..10]
      date2 = cf008[11..14]

      if type_of_date == 'r'
        years2 = extract_years_from_string(date2)
        return years2 if years2.any?
      elsif cf008_range
        return cf008_range
      else
        years1 = extract_years_from_string(date1)
        return years1 if years1.any?
      end
    end

    # 5. Check 534$c / 534$p (Original Version Note)
    record.fields('534').each do |field|
      field.find_all { |sf| %w[c p].include?(sf.code) }.each do |sf|
        years = extract_years_from_string(sf.value)
        return years if years.any?
      end
    end

    # 6. Check 264$a / 260$a (unparsed imprint statement containing date)
    record.fields('264').each do |field|
      next unless field.indicator2 == '1'
      field.find_all { |sf| sf.code == 'a' }.each do |sf|
        years = extract_years_from_string(sf.value)
        return years if years.any?
      end
    end
    record.fields('260').each do |field|
      field.find_all { |sf| sf.code == 'a' }.each do |sf|
        years = extract_years_from_string(sf.value)
        return years if years.any?
      end
    end

    # 7. Check 500$a general notes
    record.fields('500').each do |field|
      field.find_all { |sf| sf.code == 'a' }.each do |sf|
        years = extract_years_from_string(sf.value)
        return years if years.any?
      end
    end

    # 8. Check 362$a (Dates of publication / sequential designation for serials)
    record.fields('362').each do |field|
      field.find_all { |sf| sf.code == 'a' }.each do |sf|
        years = extract_years_from_string(sf.value)
        return years if years.any?
      end
    end

    # 9. Fallback to 008 Date 1 even if 'r' if no other date was found
    if (cf008 = record['008']&.value) && cf008.length >= 11
      years1 = extract_years_from_string(cf008[7..10])
      return years1 if years1.any?
    end

    []
  end

  def extract_year_from_string(str)
    years = extract_years_from_string(str)
    return nil if years.empty?

    # If copyright year was present alongside another year (e.g. "1979 printing, c1975"),
    # extract_years_from_string puts copyright year first
    years.first
  end

  def extract_years_from_string(str)
    return [] if str.blank?
    s = str.to_s.strip

    # Ignore microfilm call numbers
    return [] if s =~ /\bNJ\.FM\./i

    # Clean microfilm reel / frame references
    s_cleaned = s.gsub(/\(?Reel\s*\d+\)?/i, ' ')

    # Return empty array for known unparseable/unknown dates (e.g. [s.d.], [n.d.], [not identified], ?, ----)
    lower = s_cleaned.downcase.gsub(/[\[\]\(\)\.\,\;]/, ' ').strip
    if lower =~ /\b(s\s*d|n\s*d|sine\s+dato|no\s+date|not\s+identified|unknown|unbekannt|inconnu)\b/ ||
       s_cleaned =~ /^[\?\[\]\(\)\s\-u]+$/
      return [] unless s_cleaned =~ /\d{2}/
    end

    current_year = Time.now.year + 2

    # 1. Check for corrected date [i.e. YYYY] or [that is YYYY]
    if (match = s.match(/\[(?:i\.e\.|that is)\s*(1\d{3}|20\d{2})\]/i))
      year = match[1].to_i
      return [year] if year >= 1000 && year <= current_year
    end

    # 2. Check for 4-digit to 4-digit range (e.g., 1800-1899, c. 1800-1899, [1800-1899], 1889-1912, 1878-[1927?], [between 1800 and 1899])
    if (match = s.match(/(?<!\d)(1\d{3}|20\d{2})\s*(?:[-–—\/]|to|and|et|ou)\s*(?:c\.?\s*|ca\.?\s*|approx\.?\s*|\[)?\s*(1\d{3}|20\d{2})(?!\d)/i))
      y1 = match[1].to_i
      y2 = match[2].to_i
      if y1 <= y2 && y1 >= 1000 && y2 <= current_year
        return (y1..y2).to_a
      end
    end

    # 3. Check for 4-digit to 2-digit range (e.g., 1880-85 -> 1880..1885, 1904-05 -> 1904..1905, 1899-02 -> 1899..1902)
    if (match = s.match(/(?<!\d)(1\d{3}|20\d{2})\s*(?:[-–—\/]|to)\s*(\d{2})(?!\d)/i))
      y1 = match[1].to_i
      end_two = match[2].to_i
      century = y1 / 100
      y2 = century * 100 + end_two
      y2 += 100 if y2 < y1 && (y2 + 100) <= current_year
      if y1 <= y2 && y1 >= 1000 && y2 <= current_year
        return (y1..y2).to_a
      end
    end

    # 4. Check for decade wildcards like 189u, 189-, [189-?], 189?, 189-?] -> 1890..1899
    if (match = s_cleaned.match(/(?<!\d)(1\d{2}|20\d)[\s]*[-u\?](?!\d)/i))
      start_year = "#{match[1]}0".to_i
      end_year = ["#{match[1]}9".to_i, current_year].min
      if start_year >= 1000 && start_year <= current_year
        return (start_year..end_year).to_a
      end
    end

    # 5. Check for century wildcards like 18uu, 18--, [18--?], 18??, 18- -?, 18-?] -> 1800..1899
    if (match = s_cleaned.match(/(?<!\d)(1\d|20)[\s]*[-u\?][\s]*[-u\?](?!\d)/i)) ||
       (match = s_cleaned.match(/(?<!\d)(1\d|20)[\s]*[-u\?](?:\]|\?|\s|$)(?!\d)/i))
      start_year = "#{match[1]}00".to_i
      end_year = ["#{match[1]}99".to_i, current_year].min
      if start_year >= 1000 && start_year <= current_year
        return (start_year..end_year).to_a
      end
    end

    # 6. Check for discrete 4-digit years (e.g., 1897, c1897, [1897?], 1979 printing, c1975)
    four_digit_years = s.scan(/(?<!\d)(1\d{3}|20\d{2})(?!\d)/).flatten.map(&:to_i).uniq
    valid_years = four_digit_years.select { |y| y >= 1000 && y <= current_year }

    if valid_years.any?
      if (c_match = s.match(/[c©\bp]\s*(1\d{3}|20\d{2})/i))
        c_year = c_match[1].to_i
        if valid_years.include?(c_year)
          return [c_year] + (valid_years - [c_year]).sort
        end
      end
      return valid_years.sort
    end

    []
  end


  def materials_by_language(record)
    collection_paths_by_language(record).transform_values do |paths|
      paths.map(&:first).compact.uniq
    end
  end

  def rights_statement_facet_values(record)
    values = record.fields('540').flat_map do |field|
      field.find_all { |subfield| subfield.code == 'u' }
           .filter_map { |subfield| RightsStatementLabeler.label_for_url(subfield.value, :en) }
    end.uniq
    return values if values.present?

    record.fields('540').flat_map do |field|
      texts = field.subfields.select { |s| %w[a f].include?(s.code) }.map(&:value)
      texts.flat_map { |t| RightsStatementLabeler.labels_for_text(t) }
    end.compact_blank.uniq
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

