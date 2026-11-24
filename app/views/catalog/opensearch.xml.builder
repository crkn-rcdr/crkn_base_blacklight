# Override Blacklight's default opensearch.xml.builder so `default_url_options` (`lang`)
# never produces malformed double-`?` templates like `/catalogue/opensearch.json?lang=en?q={searchTerms}`.
xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.OpenSearchDescription(xmlns: 'http://a9.com/-/spec/opensearch/1.1/') do
  xml.ShortName application_name
  xml.Description "#{application_name} Search"
  xml.Image(asset_url('favicon.ico'), height: '16', width: '16', type: 'image/x-icon')
  xml.Contact ''
  lang = I18n.locale.to_s
  xml.Url(
    type: 'text/html',
    method: 'get',
    template: "#{search_catalog_url(lang: nil)}?q={searchTerms}&page={startPage?}&lang=#{lang}"
  )
  xml.Url(
    type: 'application/rss+xml',
    method: 'get',
    template: "#{search_catalog_url(format: 'rss', lang: nil)}?q={searchTerms}&page={startPage?}&lang=#{lang}"
  )
  xml.Url(
    type: 'application/x-suggestions+json',
    method: 'get',
    template: "#{opensearch_catalog_url(format: 'json', lang: nil)}?q={searchTerms}&lang=#{lang}"
  )
end
