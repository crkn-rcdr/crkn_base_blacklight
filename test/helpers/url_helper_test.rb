# frozen_string_literal: true

require 'test_helper'

class UrlHelperTest < ActionView::TestCase
  include ApplicationHelper
  include Blacklight::UrlHelperBehavior

  def blacklight_config
    CatalogController.blacklight_config
  end

  def search_action_path(*args)
    search_catalog_path(*args)
  end

  def current_search_session
    nil
  end

  def search_session
    {}
  end

  setup do
    controller.params = ActionController::Parameters.new
  end

  test 'url_for_document preserves active search parameters and strips search_id' do
    doc = SolrDocument.new('id' => 'oocihm.8_06959_1015')
    params[:q] = 'chocolate chip'
    params[:lang] = 'en'
    params[:search_field] = 'all_fields'
    params[:search_id] = '829'
    params[:f] = ActionController::Parameters.new({ 'format' => ['Book'] })

    url = url_for_document(doc)

    assert_includes url, 'q=chocolate+chip'
    assert_includes url, 'lang=en'
    assert_includes url, 'search_field=all_fields'
    assert_includes url, 'f%5Bformat%5D%5B%5D=Book'
    refute_includes url, 'search_id'
    refute_includes url, '829'
  end

  test 'back_to_search_url constructs return search URL directly from query parameters without search_id' do
    request.env['action_dispatch.request.query_parameters'] = {
      'q' => 'chocolate chip',
      'lang' => 'en',
      'search_field' => 'all_fields',
      'search_id' => '829',
      'id' => 'oocihm.8_06959_1015',
      'pageNum' => '12',
      'commit' => 'Search',
      'counter' => '3'
    }

    url = back_to_search_url

    assert_includes url, 'q=chocolate+chip'
    assert_includes url, 'lang=en'
    assert_includes url, 'search_field=all_fields'
    refute_includes url, 'search_id'
    refute_includes url, '829'
    refute_includes url, 'pageNum'
    refute_includes url, 'oocihm.8_06959_1015'
    refute_includes url, 'counter'
  end

  test 'session_tracking_params returns empty hash when tracking storage is false' do
    doc = SolrDocument.new('id' => 'oocihm.8_06959_1015')
    blacklight_config.track_search_session.storage = false

    tracking = session_tracking_params(doc, 1, search_id: 829)
    assert_equal({}, tracking)
  end

  test 'link_to_document carries active query parameters and strips search_id' do
    doc = SolrDocument.new('id' => 'oocihm.8_06959_1015', 'full_title_tsim' => ['A Delicious Cookie Recipe'])
    params[:q] = 'chocolate chip'
    params[:lang] = 'en'
    params[:search_id] = '829'
    params[:f] = ActionController::Parameters.new({ 'format' => ['Book'] })

    html = link_to_document(doc, 'A Delicious Cookie Recipe')

    assert_includes html, 'q=chocolate+chip'
    assert_includes html, 'lang=en'
    assert_includes html, 'f%5Bformat%5D%5B%5D=Book'
    assert_includes html, 'A Delicious Cookie Recipe'
    refute_includes html, 'search_id'
    refute_includes html, '829'
  end
end
