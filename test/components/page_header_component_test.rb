# frozen_string_literal: true

require 'test_helper'

class PageHeaderComponentTest < ViewComponent::TestCase
  def setup
    @document = SolrDocument.new(id: 'sfu.00001_19800811', full_title_tsim: ['Chinese Times : [1980-08-11]'])
    @controller = CatalogController.new
    @controller.params = ActionController::Parameters.new
    @controller.response = ActionDispatch::Response.new
    @controller.request = ActionDispatch::TestRequest.create
  end

  test 'renders safely without error when storage is false and search_session is present' do
    # When track_search_session.storage is false, applied_params_component and
    # item_pagination_component are nil. The component must not raise ArgumentError.
    CatalogController.blacklight_config.track_search_session.storage = false

    component = Blacklight::Document::PageHeaderComponent.new(
      document: @document,
      search_context: nil,
      search_session: { 'counter' => 1, 'id' => 999 }
    )

    rendered = render_inline(component)
    assert_not_nil rendered
  end

  test 'render? returns false when no components or header tools to render' do
    CatalogController.blacklight_config.track_search_session.storage = false

    component = Blacklight::Document::PageHeaderComponent.new(
      document: @document,
      search_context: nil,
      search_session: { 'counter' => 1 }
    )

    refute component.render?
  end
end
