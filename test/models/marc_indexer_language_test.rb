require "test_helper"
require "marc"

class MarcIndexerLanguageTest < ActiveSupport::TestCase
  setup do
    @indexer = MarcIndexer.new
  end

  test "extracts language from 008 positions 35-37" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0eng d'))

    doc = @indexer.map_record(record)
    assert_equal ['English'], doc['language_ssim']
  end

  test "extracts language from 041 $a when 008 is absent or undetermined" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0und d'))
    record.append(MARC::DataField.new('041', ' ', ' ', MARC::Subfield.new('a', 'fre')))

    doc = @indexer.map_record(record)
    assert_equal ['French'], doc['language_ssim']
  end

  test "extracts multi languages with 041 $b subfields" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0eng d'))
    record.append(MARC::DataField.new('041', ' ', ' ',
      MARC::Subfield.new('a', 'eng'),
      MARC::Subfield.new('b', 'fre')
    ))

    doc = @indexer.map_record(record)
    assert_equal ['English', 'French'], doc['language_ssim']
  end

  test "extracts multiple extra $b subfields in 041" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0eng d'))
    record.append(MARC::DataField.new('041', ' ', ' ',
      MARC::Subfield.new('a', 'eng'),
      MARC::Subfield.new('b', 'fre'),
      MARC::Subfield.new('b', 'ger')
    ))

    doc = @indexer.map_record(record)
    assert_equal ['English', 'French', 'German'], doc['language_ssim']
  end

  test "extracts multi languages from repeated $a subfields in 041" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0ita d'))
    record.append(MARC::DataField.new('041', '0', ' ',
      MARC::Subfield.new('a', 'ita'),
      MARC::Subfield.new('a', 'eng'),
      MARC::Subfield.new('a', 'fre')
    ))

    doc = @indexer.map_record(record)
    assert_equal ['Italian', 'English', 'French'], doc['language_ssim']
  end

  test "extracts language from 041 $d" do
    record = MARC::Record.new
    record.append(MARC::DataField.new('041', ' ', ' ',
      MARC::Subfield.new('d', 'ita')
    ))

    doc = @indexer.map_record(record)
    assert_equal ['Italian'], doc['language_ssim']
  end

  test "deduplicates identical language codes between 008 and 041" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0eng d'))
    record.append(MARC::DataField.new('041', ' ', ' ', MARC::Subfield.new('a', 'eng')))

    doc = @indexer.map_record(record)
    assert_equal ['English'], doc['language_ssim']
  end

  test "suppresses generic Multiple languages when specific languages exist in 041" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0mul d'))
    record.append(MARC::DataField.new('041', '0', ' ',
      MARC::Subfield.new('a', 'eng'),
      MARC::Subfield.new('b', 'fre')
    ))

    doc = @indexer.map_record(record)
    assert_equal ['English', 'French'], doc['language_ssim']
  end

  test "retains Multiple languages when only 008 mul is present" do
    record = MARC::Record.new
    record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0mul d'))

    doc = @indexer.map_record(record)
    assert_equal ['Multiple languages'], doc['language_ssim']
  end

  test "handles case variations and whitespace in 041 subfields" do
    record = MARC::Record.new
    record.append(MARC::DataField.new('041', ' ', ' ',
      MARC::Subfield.new('a', ' ENG '),
      MARC::Subfield.new('b', ' fre ')
    ))

    doc = @indexer.map_record(record)
    assert_equal ['English', 'French'], doc['language_ssim']
  end

  test "handles concatenated 3-character language codes in single subfield" do
    record = MARC::Record.new
    record.append(MARC::DataField.new('041', ' ', ' ',
      MARC::Subfield.new('a', 'engfre')
    ))

    doc = @indexer.map_record(record)
    assert_equal ['English', 'French'], doc['language_ssim']
  end

  test "indexes language for Heritage records from Heritage-Test.mrc if present" do
    heritage_file = [
      File.expand_path('../../config/Heritage-Test.mrc', __dir__),
      '/github/crkn_heritage_blacklight/config/Heritage-Test.mrc',
      '/platform2/marc/Heritage-Test.mrc'
    ].find { |path| File.exist?(path) }

    if heritage_file
      reader = MARC::Reader.new(heritage_file)
      count = 0
      reader.each do |record|
        doc = @indexer.map_record(record)
        assert_equal ['English'], doc['language_ssim']
        count += 1
      end
      assert_equal 5, count
    else
      # Fallback to in-memory Heritage records matching Heritage-Test.mrc
      record = MARC::Record.new
      record.append(MARC::ControlField.new('001', 'oocihm.lac_mikan_117878'))
      record.append(MARC::ControlField.new('008', '260722d99999999xx            |   a0eng d'))
      record.append(MARC::DataField.new('041', ' ', ' ', MARC::Subfield.new('a', 'eng')))
      doc = @indexer.map_record(record)
      assert_equal ['English'], doc['language_ssim']
    end
  end
end
