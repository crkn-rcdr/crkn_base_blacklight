# frozen_string_literal: true

require "test_helper"

class PageSearchComponentTest < ActiveSupport::TestCase
  test "content_search_params uses edismax with qs=0 and preserves quoted phrases" do
    component = PageSearchComponent.new(
      docId: "oocihm.test_1",
      arkUrl: "https://n2t.net/ark:/69429/m0test123",
      term: '"Barbara Howard"'
    )

    params = component.send(
      :content_search_params,
      fq: "{!terms f=manifestid}69429/m0test123",
      fl: "id,canvas_index",
      rows: 150
    )

    assert_equal "edismax", params[:defType]
    assert_equal "ocrtext ocrtext_general ocrtext_en ocrtext_fr", params[:qf]
    assert_equal 0, params[:qs]
    assert_equal false, params[:hl]
    assert_equal '"Barbara Howard"', params[:q]
    assert_nil params[:mm]
  end

  test "content_search_params normalizes pipe operator to OR and sets mm=1" do
    component = PageSearchComponent.new(
      docId: "oocihm.test_1",
      arkUrl: "https://n2t.net/ark:/69429/m0test123",
      term: "Barbara | Howard"
    )

    params = component.send(
      :content_search_params,
      fq: "{!terms f=manifestid}69429/m0test123",
      fl: "canvas_index",
      rows: 50
    )

    assert_equal "Barbara OR Howard", params[:q]
    assert_equal 1, params[:mm]
    assert_equal 0, params[:qs]
  end
end
