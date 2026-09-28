# frozen_string_literal: true

module RightsStatementLabeler
  URI_PATTERN = %r{https?://rightsstatements\.org/(?:vocab|page)/([^/?#]+)/1\.0(?:[/?#]|$)}i.freeze

  STATEMENTS_BY_CODE = {
    'cne' => {
      label: 'Copyright Not Evaluated',
      label_en: 'Copyright Not Evaluated',
      label_fr: "Droit d'auteur non évalué",
      uri_code: 'CNE',
      category: 'other',
      canonical_url: 'https://rightsstatements.org/vocab/CNE/1.0/'
    },
    'inc' => {
      label: 'In Copyright',
      label_en: 'In Copyright',
      label_fr: "Protégé par le droit d'auteur",
      uri_code: 'InC',
      category: 'in_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/InC/1.0/'
    },
    'inc-edu' => {
      label: 'In Copyright - Educational Use Permitted',
      label_en: 'In Copyright - Educational Use Permitted',
      label_fr: "Sous droit d'auteur - Utilisation éducative permise",
      uri_code: 'InC-EDU',
      category: 'in_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/InC-EDU/1.0/'
    },
    'inc-nc' => {
      label: 'In Copyright - Non-Commercial Use Permitted',
      label_en: 'In Copyright - Non-Commercial Use Permitted',
      label_fr: "Sous droit d'auteur - Utilisation non commerciale permise",
      uri_code: 'InC-NC',
      category: 'in_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/InC-NC/1.0/'
    },
    'inc-ow-eu' => {
      label: 'In Copyright - EU Orphan Work',
      label_en: 'In Copyright - EU Orphan Work',
      label_fr: "Sous droit d'auteur - Œuvre orpheline de l'UE",
      uri_code: 'InC-OW-EU',
      category: 'in_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/InC-OW-EU/1.0/'
    },
    'inc-ruu' => {
      label: 'In Copyright - Rights-holder(s) Unlocatable or Unidentifiable',
      label_en: 'In Copyright - Rights-holder(s) Unlocatable or Unidentifiable',
      label_fr: "Sous droit d'auteur - Titulaire(s) introuvable(s) ou non identifiable(s)",
      uri_code: 'InC-RUU',
      category: 'in_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/InC-RUU/1.0/'
    },
    'nkc' => {
      label: 'No Known Copyright',
      label_en: 'No Known Copyright',
      label_fr: "Aucun droit d'auteur connu",
      uri_code: 'NKC',
      category: 'other',
      canonical_url: 'https://rightsstatements.org/vocab/NKC/1.0/'
    },
    'noc-cr' => {
      label: 'No Copyright - Contractual Restrictions',
      label_en: 'No Copyright - Contractual Restrictions',
      label_fr: "Pas de droit d'auteur - Restrictions contractuelles",
      uri_code: 'NoC-CR',
      category: 'no_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/NoC-CR/1.0/'
    },
    'noc-nc' => {
      label: 'No Copyright - Non-Commercial Use Only',
      label_en: 'No Copyright - Non-Commercial Use Only',
      label_fr: "Pas de droit d'auteur - Utilisation non commerciale uniquement",
      uri_code: 'NoC-NC',
      category: 'no_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/NoC-NC/1.0/'
    },
    'noc-oklr' => {
      label: 'No Copyright - Other Known Legal Restrictions',
      label_en: 'No Copyright - Other Known Legal Restrictions',
      label_fr: "Pas de droit d'auteur - Autres restrictions juridiques connues",
      uri_code: 'NoC-OKLR',
      category: 'no_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/NoC-OKLR/1.0/'
    },
    'noc-us' => {
      label: 'No Copyright - United States',
      label_en: 'No Copyright - United States',
      label_fr: "Pas de droit d'auteur - États-Unis",
      uri_code: 'NoC-US',
      category: 'no_copyright',
      canonical_url: 'https://rightsstatements.org/vocab/NoC-US/1.0/'
    },
    'und' => {
      label: 'Copyright Undetermined',
      label_en: 'Copyright Undetermined',
      label_fr: "Droit d'auteur indéterminé",
      uri_code: 'UND',
      category: 'other',
      canonical_url: 'https://rightsstatements.org/vocab/UND/1.0/'
    },
    'ogl-canada' => {
      label: 'Open Government Licence - Canada',
      label_en: 'Open Government Licence - Canada',
      label_fr: 'Licence du gouvernement ouvert - Canada',
      uri_code: 'OGL-Canada',
      category: 'no_copyright',
      canonical_url: 'https://open.canada.ca/en/open-government-licence-canada'
    },
    'pdm' => {
      label: 'Public Domain Mark 1.0',
      label_en: 'Public Domain Mark 1.0',
      label_fr: 'Marque du domaine public 1.0',
      uri_code: 'PDM',
      category: 'no_copyright',
      canonical_url: 'https://creativecommons.org/publicdomain/mark/1.0/'
    },
    'cc0' => {
      label: 'CC0 1.0 Universal',
      label_en: 'CC0 1.0 Universal',
      label_fr: 'CC0 1.0 universel',
      uri_code: 'CC0',
      category: 'no_copyright',
      canonical_url: 'https://creativecommons.org/publicdomain/zero/1.0/'
    }
  }.freeze

  LABELS_BY_CODE = STATEMENTS_BY_CODE.transform_values { |statement| statement[:label] }.freeze
  STATEMENTS_BY_LABEL = STATEMENTS_BY_CODE.each_value.with_object({}) do |statement, index|
    index[statement[:label]] = statement
    index[statement[:label_en]] = statement if statement[:label_en]
    index[statement[:label_fr]] = statement if statement[:label_fr]
  end.freeze

  module_function

  def label_for_url(url, locale = I18n.locale)
    stmt = statement_for_url(url)
    return unless stmt

    locale.to_s.start_with?('fr') ? stmt[:label_fr] : stmt[:label_en]
  end

  def code_from_url(url)
    match = url.to_s.match(URI_PATTERN)
    return match[1].downcase.tr('l', 'i') if match

    if url.to_s =~ /open\.canada\.ca|open-government-licen|ogl-canada/i
      return 'ogl-canada'
    end

    if url.to_s =~ %r{creativecommons\.org/publicdomain/mark}i
      return 'pdm'
    end

    if url.to_s =~ %r{creativecommons\.org/publicdomain/zero}i
      return 'cc0'
    end

    nil
  end

  def statement_for_url(url)
    code = code_from_url(url)
    STATEMENTS_BY_CODE[code] if code
  end

  def statement_for_label(label)
    STATEMENTS_BY_LABEL[label.to_s]
  end

  def localized_label_for(text, locale = I18n.locale)
    stmt = statements_for_text(text).first || statement_for_label(text)
    if stmt
      locale.to_s.start_with?('fr') ? stmt[:label_fr] : stmt[:label_en]
    else
      t = text.to_s.strip
      if locale.to_s.start_with?('fr')
        case t
        when /no known copyright/i then "Aucun droit d'auteur connu"
        when /in copyright|all rights reserved/i then "Protégé par le droit d'auteur"
        when /public domain/i then "Marque du domaine public 1.0"
        when /open government/i then "Licence du gouvernement ouvert - Canada"
        else t
        end
      else
        t
      end
    end
  end

  def labels_for_text(text)
    statements = statements_for_text(text)
    return statements.map { |statement| statement[:label] }.uniq unless statements.empty?

    # Robust text fallbacks
    t = text.to_s
    if t =~ /open\.canada\.ca|open-government-licence|open government/i
      ['Open Government Licence - Canada']
    elsif t =~ %r{creativecommons\.org/publicdomain/mark}i
      ['Public Domain Mark 1.0']
    elsif t =~ %r{creativecommons\.org/publicdomain/zero}i
      ['CC0 1.0 Universal']
    elsif t =~ /no known copyright/i
      ['No Known Copyright']
    elsif t =~ /in copyright|all rights reserved|tous droits/i
      ['In Copyright']
    elsif t.present?
      cleaned = t.gsub(%r{https?://\S+}, '').strip
      [cleaned.presence || t.strip]
    else
      []
    end
  end

  def statements_for_text(text)
    t = text.to_s
    found = []

    t.scan(URI_PATTERN).flatten.each do |code|
      normalized_code = code.downcase.tr('l', 'i')
      stmt = STATEMENTS_BY_CODE[normalized_code]
      found << stmt if stmt
    end

    if t =~ /open\.canada\.ca|open-government-licen|ogl-canada|gouvernement ouvert/i
      found << STATEMENTS_BY_CODE['ogl-canada']
    end

    if t =~ %r{creativecommons\.org/publicdomain/mark|domaine public}i
      found << STATEMENTS_BY_CODE['pdm']
    end

    if t =~ %r{creativecommons\.org/publicdomain/zero}i
      found << STATEMENTS_BY_CODE['cc0']
    end

    if t =~ /no known copyright|aucun droit d'auteur/i
      found << STATEMENTS_BY_CODE['nkc']
    end

    if t =~ /in copyright|protégé par le droit d'auteur|all rights reserved|tous droits réservés/i
      found << STATEMENTS_BY_CODE['inc']
    end

    found.compact.uniq
  end

  def canonical_url_for_label(label, locale = I18n.locale)
    statement = statement_for_label(label) || statements_for_text(label).first
    return unless statement

    is_fr = locale.to_s.start_with?('fr')
    uri_code = statement[:uri_code]

    if statement[:canonical_url]&.include?('rightsstatements.org')
      lang_param = is_fr ? 'fr' : 'en'
      "https://rightsstatements.org/page/#{uri_code}/1.0/?language=#{lang_param}"
    elsif uri_code == 'OGL-Canada'
      is_fr ? 'https://open.canada.ca/fr/licence-du-gouvernement-ouvert-canada' : 'https://open.canada.ca/en/open-government-licence-canada'
    elsif uri_code == 'PDM'
      is_fr ? 'https://creativecommons.org/publicdomain/mark/1.0/deed.fr' : 'https://creativecommons.org/publicdomain/mark/1.0/'
    elsif uri_code == 'CC0'
      is_fr ? 'https://creativecommons.org/publicdomain/zero/1.0/deed.fr' : 'https://creativecommons.org/publicdomain/zero/1.0/'
    else
      statement[:canonical_url]
    end
  end

  def category_for_label(label)
    statement = statement_for_label(label) || statements_for_text(label).first
    statement&.fetch(:category, 'other') || 'other'
  end
end
