# frozen_string_literal: true

require 'test_helper'

class SearchAndShowIntegrationTest < ActionDispatch::IntegrationTest
  def heritage_portal?
    ENV['SOLR_URL'].to_s.include?('8984') ||
      ENV['SOLR_URL'].to_s.include?('heritage') ||
      ENV['BLACKLIGHT_HOST_ADDR'].to_s.include?('heritage') ||
      (defined?(CatalogController) && CatalogController.respond_to?(:heritage?) && CatalogController.heritage?(self))
  end

  def target_doc_id
    heritage_portal? ? 'oocihm.lac_reel_h2971' : 'sfu.00001_19800811'
  end

  def search_params
    if heritage_portal?
      { q: 'reel', lang: 'en' }
    else
      { q: 'chinese', f: { depositor_tsim_str: ['University of British Columbia'] }, lang: 'en' }
    end
  end

  def show_params
    if heritage_portal?
      { lang: 'en', q: 'reel', search_field: 'all_fields' }
    else
      { lang: 'en', q: 'chinese', search_field: 'all_fields', f_inclusive: { depositor_tsim_str: ['University of British Columbia'] } }
    end
  end

  test 'search with facets and navigation to item show page succeeds with 200 OK without 500 template error' do
    # 1. Simulate user executing search
    get search_catalog_path, params: search_params
    follow_redirect! if response.redirect?
    assert_response :success

    # 2. Simulate user clicking search result link to item show page
    get solr_document_path(target_doc_id), params: show_params

    # Must succeed with 200 OK without raising ArgumentError: 'nil' is not an ActiveModel-compatible object
    assert_response :success
    assert_not_includes response.body, '500 Internal Server Error'

    # 3. Verify breadcrumb root contains active query parameters and strips search_id
    assert_includes response.body, 'collection-breadcrumbs__root'
    assert_includes response.body, heritage_portal? ? 'q=reel' : 'q=chinese'
    assert_not_includes response.body, 'search_id'
  end

  test 'page chip navigation preserves f_inclusive facets and breadcrumb return' do
    # 1. User performs search with inclusive facet
    get search_catalog_path, params: search_params
    follow_redirect! if response.redirect?
    assert_response :success

    # 2. User clicks page chip link (e.g. page 2) with full search context
    chip_params = show_params.merge(pageNum: 2)
    get solr_document_path(target_doc_id), params: chip_params
    assert_response :success

    # 3. Breadcrumb return link must carry f_inclusive or search filter
    assert_includes response.body, 'collection-breadcrumbs__root'
    if heritage_portal?
      assert_includes response.body, 'q=reel'
    else
      assert_includes response.body, 'q=chinese'
      assert_includes response.body, 'University+of+British+Columbia'
    end
    assert_not_includes response.body, 'search_id'
  end

  test 'direct show page navigation with search parameters succeeds with 200 OK' do
    get solr_document_path(target_doc_id), params: show_params

    assert_response :success
    assert_not_includes response.body, '500 Internal Server Error'
  end
end
