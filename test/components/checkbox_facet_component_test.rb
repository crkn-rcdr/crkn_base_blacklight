# frozen_string_literal: true

require 'test_helper'

class CheckboxFacetComponentTest < ActiveSupport::TestCase
  class FakePaginator
    attr_reader :items

    def initialize(items, last_page: false)
      @items = items
      @last_page = last_page
    end

    def last_page?
      @last_page
    end
  end

  class FakeHelpers
    attr_reader :params

    def initialize(params)
      @params = ActionController::Parameters.new(params)
    end

    def search_action_path(p)
      "/catalogue?#{p.compact.to_query}"
    end

    def search_facet_path(p)
      id = p[:id] || p['id']
      rest = p.except(:id, 'id').compact
      "/catalogue/facet/#{id}?#{rest.to_query}"
    end

    def hidden_field_tag(name, value)
      "<input type=\"hidden\" name=\"#{name}\" value=\"#{value}\">"
    end

    def safe_join(arr)
      arr.join
    end
  end

  def build_component(params:, in_modal: false)
    facet_field = Struct.new(:key, :in_modal?, :paginator, :modal_path, :search_state).new(
      'subject_ssim_str',
      in_modal,
      FakePaginator.new([], last_page: false),
      '/catalogue/facet/subject_ssim_str',
      nil
    )
    component = CheckboxFacetComponent.new(facet_field: facet_field)
    helpers = FakeHelpers.new(params)
    component.define_singleton_method(:helpers) { helpers }
    component
  end

  test 'strips query_fragment and only_values from hidden_fields, clear_path, and more_path' do
    params = {
      'lang' => 'en',
      'q' => '',
      'search_field' => 'all_fields',
      'query_fragment' => 'lgb',
      'only_values' => true,
      'f_inclusive' => { 'subject_ssim_str' => ['LGBTQ+ communities'] }
    }

    modal_component = build_component(params: params, in_modal: true)
    refute_includes modal_component.hidden_fields, 'query_fragment'
    refute_includes modal_component.hidden_fields, 'only_values'
    refute_includes modal_component.clear_path, 'query_fragment'
    refute_includes modal_component.clear_path, 'only_values'
    refute_includes modal_component.clear_path, 'f_inclusive'

    sidebar_component = build_component(params: params, in_modal: false)
    refute_includes sidebar_component.more_path, 'query_fragment'
    refute_includes sidebar_component.more_path, 'only_values'
  end
end
