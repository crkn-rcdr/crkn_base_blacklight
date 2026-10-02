require "test_helper"
require "marc"

class MarcIndexerDateTest < ActiveSupport::TestCase
  setup do
    @indexer = MarcIndexer.new
  end

  # =========================================================================
  # extract_year_from_string tests
  # =========================================================================
  test "extracts standard 4-digit years" do
    assert_equal 1897, @indexer.send(:extract_year_from_string, "1897")
    assert_equal 1897, @indexer.send(:extract_year_from_string, "[1897]")
    assert_equal 1897, @indexer.send(:extract_year_from_string, "1897.")
    assert_equal 1897, @indexer.send(:extract_year_from_string, "[1897?]")
    assert_equal 1897, @indexer.send(:extract_year_from_string, "1897?")
  end

  test "extracts copyright and phonogram dates" do
    assert_equal 1897, @indexer.send(:extract_year_from_string, "c1897")
    assert_equal 1897, @indexer.send(:extract_year_from_string, "©1897")
    assert_equal 1983, @indexer.send(:extract_year_from_string, "Ⓟ1983")
    assert_equal 1975, @indexer.send(:extract_year_from_string, "1979 printing, c1975")
  end

  test "extracts corrected publication dates" do
    assert_equal 1971, @indexer.send(:extract_year_from_string, "1968 [i.e. 1971]")
    assert_equal 1971, @indexer.send(:extract_year_from_string, "1968 [that is 1971]")
  end

  test "extracts dates from ranges" do
    assert_equal 1800, @indexer.send(:extract_year_from_string, "c. 1800-1899")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "1800-1899")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "[between 1800 and 1899]")
    assert_equal 1889, @indexer.send(:extract_year_from_string, "1889-1912")
    assert_equal 1878, @indexer.send(:extract_year_from_string, "1878-[1927?]")
    assert_equal 1980, @indexer.send(:extract_year_from_string, "1980-")
    assert_equal 1981, @indexer.send(:extract_year_from_string, "<1981- >")
  end

  test "extracts dates with approximate or verbal prefixes" do
    assert_equal 1920, @indexer.send(:extract_year_from_string, "[ca. 1920]")
    assert_equal 1850, @indexer.send(:extract_year_from_string, "ca. 1850")
    assert_equal 1977, @indexer.send(:extract_year_from_string, "April 15, 1977")
  end

  test "extracts decade wildcard dates" do
    assert_equal 1890, @indexer.send(:extract_year_from_string, "189-")
    assert_equal 1890, @indexer.send(:extract_year_from_string, "[189-]")
    assert_equal 1890, @indexer.send(:extract_year_from_string, "189-?]")
    assert_equal 1890, @indexer.send(:extract_year_from_string, "[189-?]")
    assert_equal 1890, @indexer.send(:extract_year_from_string, "189?]")
    assert_equal 1890, @indexer.send(:extract_year_from_string, "[189?]")
    assert_equal 1890, @indexer.send(:extract_year_from_string, "189u")
  end

  test "extracts century wildcard dates" do
    assert_equal 1800, @indexer.send(:extract_year_from_string, "18--")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "[18--]")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "18--?]")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "[18--?]")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "18--]")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "18uu")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "18??")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "[18- -?]")
    assert_equal 1800, @indexer.send(:extract_year_from_string, "18-?]")
  end

  test "returns nil for legitimate unknown publication dates" do
    assert_nil @indexer.send(:extract_year_from_string, "[s.d.]")
    assert_nil @indexer.send(:extract_year_from_string, "s.d.")
    assert_nil @indexer.send(:extract_year_from_string, "[n.d.]")
    assert_nil @indexer.send(:extract_year_from_string, "n.d.")
    assert_nil @indexer.send(:extract_year_from_string, "[date of publication not identified]")
    assert_nil @indexer.send(:extract_year_from_string, "[not identified]")
    assert_nil @indexer.send(:extract_year_from_string, "?")
    assert_nil @indexer.send(:extract_year_from_string, "[?]")
    assert_nil @indexer.send(:extract_year_from_string, "unknown")
    assert_nil @indexer.send(:extract_year_from_string, "")
    assert_nil @indexer.send(:extract_year_from_string, nil)
  end

  # =========================================================================
  # extract_original_publication_year on full MARC record
  # =========================================================================
  test "extracts year from 264$c with dashed century" do
    record = MARC::Record.new
    field = MARC::DataField.new('264', ' ', '1',
      MARC::Subfield.new('a', 'Portland, Me. : '),
      MARC::Subfield.new('b', 'Chisholm, '),
      MARC::Subfield.new('c', '18--?]')
    )
    record.append(field)
    record.append(MARC::ControlField.new('008', '180921r2018    meua    o     000 0 eng d'))

    assert_equal 1800, @indexer.send(:extract_original_publication_year, record)
  end

  test "extracts year from 264$c with dashed decade" do
    record = MARC::Record.new
    field = MARC::DataField.new('264', ' ', '1',
      MARC::Subfield.new('a', '[S.l. :'),
      MARC::Subfield.new('b', 'publisher not identified,'),
      MARC::Subfield.new('c', '189-?]')
    )
    record.append(field)
    record.append(MARC::ControlField.new('008', '180921r2018    xx      o     000 0 fre d'))

    assert_equal 1890, @indexer.send(:extract_original_publication_year, record)
  end

  test "extracts year from 264$a when subfield c is absent" do
    record = MARC::Record.new
    field = MARC::DataField.new('264', ' ', '1',
      MARC::Subfield.new('a', 'Regina, Sask. : University of Saskatchewan, Regina Campus, 1962')
    )
    record.append(field)

    assert_equal 1962, @indexer.send(:extract_original_publication_year, record)
  end

  # =========================================================================
  # extract_publication_years and extract_years_from_string expansion tests
  # =========================================================================
  test "expands full century range 1800-1899 without 20-30 year limits" do
    years = @indexer.send(:extract_years_from_string, "c. 1800-1899")
    assert_equal 100, years.size
    assert_equal 1800, years.first
    assert_equal 1899, years.last
    assert_equal (1800..1899).to_a, years
  end

  test "expands decade wildcards to 10 intermediate years" do
    years = @indexer.send(:extract_years_from_string, "[189-?]")
    assert_equal 10, years.size
    assert_equal (1890..1899).to_a, years
  end

  test "expands century wildcards to 100 intermediate years" do
    years = @indexer.send(:extract_years_from_string, "18--?]")
    assert_equal 100, years.size
    assert_equal (1800..1899).to_a, years
  end

  test "expands 2-digit end year ranges" do
    years = @indexer.send(:extract_years_from_string, "1880-85")
    assert_equal 6, years.size
    assert_equal (1880..1885).to_a, years
  end

  test "expands full range on MARC record with 264$c range" do
    record = MARC::Record.new
    record.append(MARC::DataField.new('264', ' ', '1',
      MARC::Subfield.new('a', 'London :'),
      MARC::Subfield.new('c', 'c. 1800-1899')
    ))

    assert_equal (1800..1899).to_a, @indexer.send(:extract_publication_years, record)
    assert_equal 1800, @indexer.send(:extract_original_publication_year, record)
  end

  test "expands 008 multi-date 'm' range on MARC record" do
    record = MARC::Record.new
    record.append(MARC::DataField.new('264', ' ', '1',
      MARC::Subfield.new('c', '1880')
    ))
    record.append(MARC::ControlField.new('008', '180921m18801885xx      o     000 0 eng d'))

    assert_equal (1880..1885).to_a, @indexer.send(:extract_publication_years, record)
    assert_equal 1880, @indexer.send(:extract_original_publication_year, record)
  end
end

