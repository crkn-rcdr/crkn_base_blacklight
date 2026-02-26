class MembersComponent < ViewComponent::Base
  require 'zlib'

  LOGO_ASSETS = {
    'Acadia University' => 'members/acadia-university.png',
    'Algoma University' => 'members/algoma-university.png',
    'Athabasca University' => 'members/athabasca-university.png',
    'Bibliotheque et Archives nationales du Quebec' => 'members/bibliotheque-et-archives-nationales-du-quebec.png',
    "Bishop's University" => 'members/bishop-s-university.png',
    'Brandon University' => 'members/brandon-university.png',
    'Brock University' => 'members/brock-university.png',
    'Cape Breton University' => 'members/cape-breton-university.png',
    'Capilano University' => 'members/capilano-university.png',
    'Carleton University' => 'members/carleton-university.png',
    'Concordia University' => 'members/concordia-university.png',
    'Concordia University of Edmonton' => 'members/concordia-university-of-edmonton.png',
    'Dalhousie University' => 'members/dalhousie-university.png',
    'Ecole Polytechnique de Montreal' => 'members/ecole-polytechnique-de-montreal.png',
    'Ecole de technologie superieure (UQ)' => 'members/ecole-de-technologie-superieure-uq.png',
    "Ecole nationale d'administration publique (UQ)" => 'members/ecole-nationale-d-administration-publique-uq.png',
    'HEC Montreal' => 'members/hec-montreal.png',
    'Institut national de la recherche scientifique (UQ)' => 'members/institut-national-de-la-recherche-scientifique-uq.png',
    'Kwantlen Polytechnic University' => 'members/kwantlen-polytechnic-university.png',
    'Lakehead University' => 'members/lakehead-university.png',
    'Laurentian University' => 'members/laurentian-university.png',
    'Library and Archives Canada' => 'members/library-and-archives-canada.png',
    'MacEwan University' => 'members/macewan-university.png',
    'McGill University' => 'members/mcgill-university.png',
    'McMaster University' => 'members/mcmaster-university.png',
    'Memorial University of Newfoundland' => 'members/memorial-university-of-newfoundland.png',
    'Mount Allison University' => 'members/mount-allison-university.png',
    'Mount Royal University' => 'members/mount-royal-university.png',
    'Mount Saint Vincent University' => 'members/mount-saint-vincent-university.png',
    'Nipissing University' => 'members/nipissing-university.png',
    'Nova Scotia College of Art and Design University' => 'members/nova-scotia-college-of-art-and-design-university.png',
    'OCAD University' => 'members/ocad-university.png',
    'Ontario Tech University' => 'members/ontario-tech-university.png',
    "Queen's University" => 'members/queen-s-university.png',
    'Royal Military College of Canada' => 'members/royal-military-college-of-canada.png',
    'Royal Roads University' => 'members/royal-roads-university.png',
    "Saint Mary's University" => 'members/saint-mary-s-university.png',
    'Simon Fraser University' => 'members/simon-fraser-university.png',
    'St. Francis Xavier University' => 'members/st-francis-xavier-university.png',
    'Tele-universite du Quebec' => 'members/tele-universite-du-quebec.png',
    "The King's University" => 'members/the-king-s-university.png',
    'Thompson Rivers University' => 'members/thompson-rivers-university.png',
    'Toronto Metropolitan University' => 'members/toronto-metropolitan-university.png',
    'Toronto Public Library' => 'members/toronto-public-library.png',
    'Trent University' => 'members/trent-university.png',
    'Trinity Western University' => 'members/trinity-western-university.png',
    'Universite Laval' => 'members/universite-laval.png',
    'Universite Sainte-Anne' => 'members/universite-sainte-anne.png',
    'Universite de Moncton' => 'members/universite-de-moncton.png',
    'Universite de Montreal' => 'members/universite-de-montreal.png',
    'Universite de Sherbrooke' => 'members/universite-de-sherbrooke.png',
    'Universite du Quebec a Chicoutimi' => 'members/universite-du-quebec-a-chicoutimi.png',
    'Universite du Quebec a Montreal' => 'members/universite-du-quebec-a-montreal.png',
    'Universite du Quebec a Rimouski' => 'members/universite-du-quebec-a-rimouski.png',
    'Universite du Quebec a Trois-Rivieres' => 'members/universite-du-quebec-a-trois-rivieres.png',
    'Universite du Quebec en Abitibi-Temiscamingue' => 'members/universite-du-quebec-en-abitibi-temiscamingue.png',
    'Universite du Quebec en Outaouais' => 'members/universite-du-quebec-en-outaouais.png',
    'University of Alberta' => 'members/university-of-alberta.png',
    'University of British Columbia' => 'members/university-of-british-columbia.png',
    'University of Calgary' => 'members/university-of-calgary.png',
    'University of Guelph' => 'members/university-of-guelph.png',
    'University of Lethbridge' => 'members/university-of-lethbridge.png',
    'University of Manitoba' => 'members/university-of-manitoba.png',
    'University of New Brunswick' => 'members/university-of-new-brunswick.png',
    'University of Northern British Columbia' => 'members/university-of-northern-british-columbia.png',
    'University of Ottawa' => 'members/university-of-ottawa.png',
    'University of Prince Edward Island' => 'members/university-of-prince-edward-island.png',
    'University of Regina' => 'members/university-of-regina.png',
    'University of Saskatchewan' => 'members/university-of-saskatchewan.png',
    'University of Toronto' => 'members/university-of-toronto.png',
    'University of Victoria' => 'members/university-of-victoria.png',
    'University of Waterloo' => 'members/university-of-waterloo.png',
    'University of Windsor' => 'members/university-of-windsor.png',
    'University of Winnipeg' => 'members/university-of-winnipeg.png',
    'University of the Fraser Valley' => 'members/university-of-the-fraser-valley.png',
    'Vancouver Island University' => 'members/vancouver-island-university.png',
    'Western University' => 'members/western-university.png',
    'Wilfrid Laurier University' => 'members/wilfrid-laurier-university.png',
    'York University' => 'members/york-university.png',
    'Yukon University' => 'members/yukon-university.png'
  }.freeze

  MEMBER_URLS = {
    'Acadia University' => 'https://www2.acadiau.ca/',
    'Algoma University' => 'https://algomau.ca/',
    'Athabasca University' => 'https://www.athabascau.ca/',
    'Bibliotheque et Archives nationales du Quebec' => 'https://www.banq.qc.ca/',
    "Bishop's University" => 'https://www.ubishops.ca/',
    'Brandon University' => 'https://www.brandonu.ca/',
    'Brock University' => 'https://brocku.ca/',
    'Cape Breton University' => 'https://www.cbu.ca/',
    'Capilano University' => 'https://www.capilanou.ca/',
    'Carleton University' => 'https://carleton.ca/',
    'Concordia University' => 'https://www.concordia.ca/',
    'Concordia University of Edmonton' => 'https://www.concordia.ab.ca/',
    'Dalhousie University' => 'https://www.dal.ca/',
    'Ecole Polytechnique de Montreal' => 'https://www.polymtl.ca/',
    "Ecole nationale d'administration publique (UQ)" => 'https://www.enap.ca/',
    'Ecole de technologie superieure (UQ)' => 'https://www.etsmtl.ca/',
    'HEC Montreal' => 'https://www.hec.ca/',
    'Institut national de la recherche scientifique (UQ)' => 'https://inrs.ca/',
    'Kwantlen Polytechnic University' => 'https://www.kpu.ca/',
    'Lakehead University' => 'https://www.lakeheadu.ca/',
    'Laurentian University' => 'https://laurentian.ca/',
    'Library and Archives Canada' => 'https://library-archives.canada.ca/',
    'Library of Parliament' => 'https://lop.parl.ca/',
    'MacEwan University' => 'https://www.macewan.ca/',
    'McGill University' => 'https://www.mcgill.ca/',
    'McMaster University' => 'https://www.mcmaster.ca/',
    'Memorial University of Newfoundland' => 'https://www.mun.ca/',
    'Mount Allison University' => 'https://www.mta.ca/',
    'Mount Royal University' => 'https://www.mtroyal.ca/',
    'Mount Saint Vincent University' => 'https://www.msvu.ca/',
    'National Research Council Canada' => 'https://nrc.canada.ca/',
    'Nipissing University' => 'https://www.nipissingu.ca/',
    'NOSM University' => 'https://www.nosm.ca/',
    'Nova Scotia College of Art and Design University' => 'https://nscad.ca/',
    'OCAD University' => 'https://www.ocadu.ca/',
    'Ontario Tech University' => 'https://ontariotechu.ca/',
    'OurDigitalWorld' => 'https://ourdigitalworld.net/',
    "Queen's University" => 'https://www.queensu.ca/',
    'Research and Development Institute for the Agri-environment' => 'https://www.irda.qc.ca/',
    'Royal Military College of Canada' => 'https://www.rmc-cmr.ca/',
    'Royal Roads University' => 'https://www.royalroads.ca/',
    "Saint Mary's University" => 'https://www.smu.ca/',
    'Simon Fraser University' => 'https://www.sfu.ca/',
    'St. Francis Xavier University' => 'https://www.stfx.ca/',
    'Tele-universite du Quebec' => 'https://teluq.ca/',
    "The King's University" => 'https://www.kingsu.ca/',
    'Thompson Rivers University' => 'https://www.tru.ca/',
    'Toronto Metropolitan University' => 'https://www.torontomu.ca/',
    'Toronto Public Library' => 'https://www.tpl.ca/',
    'Trent University' => 'https://www.trentu.ca/',
    'Trinity Western University' => 'https://www.twu.ca/',
    'Universite Laval' => 'https://www.ulaval.ca/',
    'Universite Sainte-Anne' => 'https://www.usainteanne.ca/',
    'Universite de Hearst' => 'https://www.uhearst.ca/',
    'Universite de Moncton' => 'https://www.umoncton.ca/',
    'Universite de Montreal' => 'https://www.umontreal.ca/',
    'Universite de Sherbrooke' => 'https://www.usherbrooke.ca/',
    "Universite de l'Ontario francais" => 'https://uontario.ca/',
    'Universite du Quebec a Chicoutimi' => 'https://www.uqac.ca/',
    'Universite du Quebec a Montreal' => 'https://uqam.ca/',
    'Universite du Quebec a Rimouski' => 'https://www.uqar.ca/',
    'Universite du Quebec a Trois-Rivieres' => 'https://www.uqtr.ca/',
    'Universite du Quebec en Abitibi-Temiscamingue' => 'https://www.uqat.ca/',
    'Universite du Quebec en Outaouais' => 'https://uqo.ca/',
    'University of Alberta' => 'https://www.ualberta.ca/',
    'University of British Columbia' => 'https://www.ubc.ca/',
    'University of Calgary' => 'https://www.ucalgary.ca/',
    'University of Guelph' => 'https://www.uoguelph.ca/',
    'University of Lethbridge' => 'https://www.ulethbridge.ca/',
    'University of Manitoba' => 'https://umanitoba.ca/',
    'University of New Brunswick' => 'https://www.unb.ca/',
    'University of Northern British Columbia' => 'https://www.unbc.ca/',
    'University of Ottawa' => 'https://www.uottawa.ca/',
    'University of Prince Edward Island' => 'https://www.upei.ca/',
    'University of Regina' => 'https://www.uregina.ca/',
    'University of Saskatchewan' => 'https://www.usask.ca/',
    'University of Toronto' => 'https://www.utoronto.ca/',
    'University of Victoria' => 'https://www.uvic.ca/',
    'University of Waterloo' => 'https://uwaterloo.ca/',
    'University of Windsor' => 'https://www.uwindsor.ca/',
    'University of Winnipeg' => 'https://www.uwinnipeg.ca/',
    'University of the Fraser Valley' => 'https://www.ufv.ca/',
    'Vancouver Island University' => 'https://www.viu.ca/',
    'Western University' => 'https://www.uwo.ca/',
    'Wilfrid Laurier University' => 'https://www.wlu.ca/',
    'York University' => 'https://www.yorku.ca/',
    'Yukon University' => 'https://www.yukonu.ca/'
  }.freeze

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

  def logo_asset(name)
    LOGO_ASSETS[normalize_name(name)]
  end

  def member_url(member)
    explicit = member['url'].to_s.strip
    return explicit if explicit.present?

    MEMBER_URLS[normalize_name(member['name'])]
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
