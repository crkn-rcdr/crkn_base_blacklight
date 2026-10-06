require "test_helper"
require "marc"

class MarcIndexerIssueSortTest < Minitest::Test
  def setup
    @indexer = MarcIndexer.new
  end

  def test_indexes_zero_padded_issue_sort_and_issue_seq_for_issues
    rec = MARC::Record.new
    rec.append(MARC::ControlField.new("001", "oocihm.8_05016_2"))
    rec.append(MARC::DataField.new("901", " ", " ", ["a", "Is issue"]))

    output = @indexer.map_record(rec)
    assert_equal ["oocihm.0000000008_0000005016_0000000002"], output["issue_sort_s"]
    assert_equal [2], output["issue_seq_i"]
  end

  def test_natural_sort_order_holds_for_single_vs_double_digit_issue_numbers
    rec1 = MARC::Record.new
    rec1.append(MARC::ControlField.new("001", "oocihm.8_05016_2"))
    rec1.append(MARC::DataField.new("901", " ", " ", ["a", "Is issue"]))

    rec2 = MARC::Record.new
    rec2.append(MARC::ControlField.new("001", "oocihm.8_05016_10"))
    rec2.append(MARC::DataField.new("901", " ", " ", ["a", "Is issue"]))

    sort1 = @indexer.map_record(rec1)["issue_sort_s"]&.first
    sort2 = @indexer.map_record(rec2)["issue_sort_s"]&.first

    assert sort1 < sort2, "Expected #{sort1} < #{sort2}"
  end

  def test_indexes_issue_sort_and_issue_seq_for_newspaper_date_issues
    rec = MARC::Record.new
    rec.append(MARC::ControlField.new("001", "oocihm.N_00123_18800101"))
    rec.append(MARC::DataField.new("901", " ", " ", ["a", "Is issue"]))

    output = @indexer.map_record(rec)
    assert_equal ["oocihm.N_0000000123_0018800101"], output["issue_sort_s"]
    assert_equal [18800101], output["issue_seq_i"]
  end

  def test_does_not_index_issue_sort_for_non_issue_records
    rec = MARC::Record.new
    rec.append(MARC::ControlField.new("001", "oocihm.8_05016"))
    rec.append(MARC::DataField.new("901", " ", " ", ["a", "Is series"]))

    output = @indexer.map_record(rec)
    assert_nil output["issue_sort_s"]
    assert_nil output["issue_seq_i"]
  end

  def test_collection_items_component_native_solr_pagination
    comp = CollectionItemsComponent.new(documentId: "mw.00001", page: 1, per_page: 12)
    assert_equal 43, comp.total_items
    assert_equal 4, comp.total_pages
    assert_equal 1, comp.page
    assert_equal 12, comp.per_page
    assert_equal 12, comp.collection_items.length
    assert_equal "mw.00001_1", comp.collection_items.first["id"]

    page2 = CollectionItemsComponent.new(documentId: "mw.00001", page: 2, per_page: 12)
    assert_equal 43, page2.total_items
    assert_equal 12, page2.collection_items.length
    assert_equal "mw.00001_13", page2.collection_items.first["id"]
  end

  def test_collection_items_component_blank_document_id
    comp = CollectionItemsComponent.new(documentId: "", page: 1, per_page: 12)
    assert_equal 0, comp.total_items
    assert_equal 0, comp.total_pages
    assert_empty comp.collection_items
  end
end
