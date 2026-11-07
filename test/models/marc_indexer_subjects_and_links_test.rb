require "test_helper"
require "marc"

class MarcIndexerSubjectsAndLinksTest < ActiveSupport::TestCase
  setup do
    @indexer = MarcIndexer.new
  end

  # =========================================================================
  # Issue #107: Subject Subdivision Separator (" -- ")
  # =========================================================================
  test "formats subject subdivisions ($v, $x, $y, $z) with ' -- ' separator" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('001', +'oocihm.test001'))
    record.append(
      MARC::DataField.new(
        '650', ' ', '0',
        MARC::Subfield.new('a', +'Single women'),
        MARC::Subfield.new('v', +'Comic books, strips, etc.')
      )
    )

    doc = @indexer.map_record(record)
    assert_includes doc['subject_ssim'], 'Single women -- Comic books, strips, etc.'
    assert_includes doc['subject_tsim'], 'Single women -- Comic books, strips, etc.'
  end

  test "formats multi-level subject subdivisions ($x, $y, $z, $v) with ' -- '" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('001', +'oocihm.test002'))
    record.append(
      MARC::DataField.new(
        '651', ' ', '0',
        MARC::Subfield.new('a', +'Canada.'),
        MARC::Subfield.new('x', +'History.'),
        MARC::Subfield.new('y', +'1763-1791.'),
        MARC::Subfield.new('v', +'Sources.')
      )
    )

    doc = @indexer.map_record(record)
    assert_includes doc['subject_ssim'], 'Canada -- History -- 1763-1791 -- Sources'
    assert_includes doc['subject_tsim'], 'Canada -- History -- 1763-1791 -- Sources'
  end

  test "formats geographic and topical subdivisions with ' -- '" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('001', +'oocihm.test003'))
    record.append(
      MARC::DataField.new(
        '650', ' ', '0',
        MARC::Subfield.new('a', +'Mines and mineral resources'),
        MARC::Subfield.new('z', +'Ontario'),
        MARC::Subfield.new('z', +'Silver Islet.')
      )
    )

    doc = @indexer.map_record(record)
    assert_includes doc['subject_ssim'], 'Mines and mineral resources -- Ontario -- Silver Islet'
  end

  # =========================================================================
  # Issue #97: 7XX Linking Entries, Indicator Relationships & $w
  # =========================================================================
  test "formats 785 succeeding entry with indicator 2 relationship and $w control number" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('001', +'oocihm.test004'))
    record.append(
      MARC::DataField.new(
        '785', '0', '0',
        MARC::Subfield.new('t', +'Canadian Labor leader'),
        MARC::Subfield.new('w', +'oocihm.N_00559.')
      )
    )

    doc = @indexer.map_record(record)
    assert_includes doc['related_items_tsim'], 'Continued by: Canadian Labor leader (oocihm.N_00559)'
  end

  test "formats 775 other edition entry with $w control number" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('001', +'oocihm.test005'))
    record.append(
      MARC::DataField.new(
        '775', '0', ' ',
        MARC::Subfield.new('t', +'Morning star'),
        MARC::Subfield.new('w', +'oocihm.N_00055.')
      )
    )

    doc = @indexer.map_record(record)
    assert_includes doc['related_items_tsim'], 'Other edition: Morning star (oocihm.N_00055)'
  end

  test "formats 780 preceding entry with indicator 2 relationship" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('001', +'oocihm.test006'))
    record.append(
      MARC::DataField.new(
        '780', '0', '0',
        MARC::Subfield.new('t', +'Weekly Gazette'),
        MARC::Subfield.new('w', +'oocihm.N_00010')
      )
    )

    doc = @indexer.map_record(record)
    assert_includes doc['related_items_tsim'], 'Continues: Weekly Gazette (oocihm.N_00010)'
  end

  test "formats linking entry without $w when not available" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('001', +'oocihm.test007'))
    record.append(
      MARC::DataField.new(
        '785', '0', '0',
        MARC::Subfield.new('t', +'The Daily News')
      )
    )

    doc = @indexer.map_record(record)
    assert_includes doc['related_items_tsim'], 'Continued by: The Daily News'
  end

  # =========================================================================
  # Issue #106: Search Result Stub Fields
  # =========================================================================
  test "stub fields are correctly configured in catalog controller" do
    index_fields = CatalogController.blacklight_config.index_fields
    assert index_fields.key?('format')
    assert index_fields.key?('published_ssm')
    assert index_fields.key?('depositor_tsim')
    assert index_fields.key?('id')

    # Removed fields from stubs per Natalie / Adele
    refute index_fields.key?('original_version_note_tsim')
    refute index_fields.key?('access_note_tsim')
    refute index_fields.key?('ark')
    refute index_fields.key?('date_added')
  end
end
