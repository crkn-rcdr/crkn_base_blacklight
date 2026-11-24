# frozen_string_literal: true

require 'test_helper'

class LocaleAndOpensearchTest < ActionDispatch::IntegrationTest
  test 'opensearch.xml emits valid single-? URL templates without ?lang=en?q= corruption' do
    get '/catalogue/opensearch.xml?lang=en'
    assert_response :success
    assert_no_match(/\?lang=[a-z]+\?q=/, response.body)
    assert_includes response.body, '/catalogue/opensearch.json?q={searchTerms}&amp;lang=en'
    assert_includes response.body, '/catalogue?q={searchTerms}&amp;page={startPage?}&amp;lang=en'
    assert_includes response.body, '/catalogue.rss?q={searchTerms}&amp;page={startPage?}&amp;lang=en'
  end

  test 'malformed ?lang=en?q=term does not raise I18n::InvalidLocale' do
    get '/catalogue/opensearch.xml?lang=en?q=manitoba'
    assert_response :success
    assert_equal :en, I18n.locale
  end

  test 'unknown locale parameter falls back cleanly without HTTP 500' do
    get '/catalogue/opensearch.xml?lang=xx_invalid'
    assert_response :success
    assert_includes I18n.available_locales, I18n.locale
  end

  test 'CatalogController uses HTTP POST to Solr to prevent 414 Request-URI Too Long' do
    assert_equal :post, CatalogController.blacklight_config.http_method
  end
end
