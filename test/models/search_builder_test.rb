# frozen_string_literal: true

require "test_helper"

class SearchBuilderTest < ActiveSupport::TestCase
  def setup
    @controller = CatalogController.new
  end

  test "apply_fulltext_join transforms all_fields query into lucene with content_search join and serial join" do
    @controller.params = ActionController::Parameters.new({ q: "chocolate chip", search_field: "all_fields" })
    builder = SearchBuilder.new(@controller).with({ q: "chocolate chip", search_field: "all_fields" })
    params = builder.processed_parameters

    assert_equal "lucene", params[:defType]
    assert_includes params[:q_meta], "chocolate chip"
    assert_equal "chocolate chip", params[:fulltext_q]
    assert_includes params[:q], '_query_:"{!join from=manifestid to=manifestid_s fromIndex=content_search score=max v=$q_fulltext}"'
    assert_includes params[:q], '_query_:"{!join from=serial_key_s to=id v=\'{!join from=manifestid to=manifestid_s fromIndex=content_search score=max v=$q_fulltext}\'}"'
    assert_includes params[:q], '_query_:"{!edismax qf=$all_fields_qf pf=$all_fields_pf qs=0 v=$q_meta}"^2'
    assert_includes params[:q_fulltext], 'qs=0'
    assert_equal 0, params[:qs]
  end

  test "apply_fulltext_join transforms blank search_field query into lucene with fulltext joins" do
    @controller.params = ActionController::Parameters.new({ q: "treaty" })
    builder = SearchBuilder.new(@controller).with({ q: "treaty" })
    params = builder.processed_parameters

    assert_equal "lucene", params[:defType]
    assert_includes params[:q_meta], "treaty"
    assert_equal "treaty", params[:fulltext_q]
    assert_includes params[:q], 'fromIndex=content_search'
  end

  test "apply_fulltext_join transforms tx_gen search_field into content_search and serial join" do
    @controller.params = ActionController::Parameters.new({ q: "treaty", search_field: "tx_gen" })
    builder = SearchBuilder.new(@controller).with({ q: "treaty", search_field: "tx_gen" })
    params = builder.processed_parameters

    assert_equal "lucene", params[:defType]
    assert_equal "treaty", params[:fulltext_q]
    assert_includes params[:q], '_query_:"{!join from=manifestid to=manifestid_s fromIndex=content_search score=max v=$q_fulltext}"'
    assert_includes params[:q], '_query_:"{!join from=serial_key_s to=id'
    assert_not_includes params[:q], 'q_meta'
  end

  test "apply_fulltext_join leaves wildcard *:* as frange filter for tx_gen" do
    @controller.params = ActionController::Parameters.new({ q: "*:*", search_field: "tx_gen" })
    builder = SearchBuilder.new(@controller).with({ q: "*:*", search_field: "tx_gen" })
    params = builder.processed_parameters

    assert_equal "lucene", params[:defType]
    assert_equal "{!frange l=1}has_full_text_eff", params[:q]
  end

  test "apply_fulltext_join ignores empty or wildcard queries for all_fields" do
    @controller.params = ActionController::Parameters.new({ q: "*:*", search_field: "all_fields" })
    builder = SearchBuilder.new(@controller).with({ q: "*:*", search_field: "all_fields" })
    params = builder.processed_parameters

    assert_not_equal "lucene", params[:defType]
  end

  test "apply_fulltext_join uses score=none when sorting by date fields" do
    %w[year-desc year-asc date-added-desc date-added-asc].each do |sort_key|
      @controller.params = ActionController::Parameters.new({ q: "canada", search_field: "all_fields", sort: sort_key })
      builder = SearchBuilder.new(@controller).with({ q: "canada", search_field: "all_fields", sort: sort_key })
      params = builder.processed_parameters

      assert_includes params[:q], "fromIndex=content_search score=none", "Expected score=none for sort=#{sort_key}"
      assert_not_includes params[:q], "fromIndex=content_search score=max", "Did not expect score=max for sort=#{sort_key}"
    end
  end

  test "apply_fulltext_join keeps score=max when sorting by relevance" do
    @controller.params = ActionController::Parameters.new({ q: "canada", search_field: "all_fields", sort: "relevance" })
    builder = SearchBuilder.new(@controller).with({ q: "canada", search_field: "all_fields", sort: "relevance" })
    params = builder.processed_parameters

    assert_includes params[:q], "fromIndex=content_search score=max"
  end

  test "internal document ID fetch queries (citation/bookmarks) bypass fulltext join and request fl=*" do
    builder = SearchBuilder.new(@controller).where(id: ["oon.00002_194801"])
    params = builder.processed_parameters

    assert_equal '{!lucene}id:("oon.00002_194801")', params[:q]
    assert_equal '*', params[:fl]
    assert_equal false, params[:facet]
    assert_nil params[:fulltext_q]
    assert_nil params[:q_meta]
  end

  test "quoted phrase queries enforce exact phrase slop qs=0 across all_fields, tx_gen, and title" do
    %w[all_fields tx_gen title].each do |field|
      @controller.params = ActionController::Parameters.new({ q: '"Barbara Howard"', search_field: field })
      builder = SearchBuilder.new(@controller).with({ q: '"Barbara Howard"', search_field: field })
      params = builder.processed_parameters

      assert_equal 0, params[:qs], "Expected qs=0 for search_field=#{field}"
      if field == "all_fields" || field == "tx_gen"
        assert_equal '"Barbara Howard"', params[:fulltext_q]
        assert_includes params[:q_fulltext], "qs=0"
      end
    end
  end

  test "long 40-word historical titles are preserved intact without truncation" do
    title_q = Array.new(40) { |i| "titleword#{i}" }.join(' ')
    @controller.params = ActionController::Parameters.new({ q: title_q, search_field: "all_fields" })
    builder = SearchBuilder.new(@controller).with({ q: title_q, search_field: "all_fields" })
    params = builder.processed_parameters

    assert_equal 40, params[:fulltext_q].split(/\s+/).length
  end

  test "very long pasted queries are safely capped to MAX_QUERY_WORDS with balanced quotes" do
    long_q = '"' + Array.new(80) { |i| "word#{i}" }.join(' ') + '"'
    @controller.params = ActionController::Parameters.new({ q: long_q, search_field: "all_fields" })
    builder = SearchBuilder.new(@controller).with({ q: long_q, search_field: "all_fields" })
    params = builder.processed_parameters

    assert_equal SearchBuilder::MAX_QUERY_WORDS, params[:fulltext_q].split(/\s+/).length
    assert_equal 0, params[:fulltext_q].count('"') % 2
  end
end
