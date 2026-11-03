# frozen_string_literal: true

require 'test_helper'

class FormatTextTest < ActionView::TestCase
  include ApplicationHelper

  test 'formats single note into a metadata-paragraph' do
    doc = SolrDocument.new(
      'id' => '123',
      'notes_tsim' => ['Single note entry.']
    )
    result = format_text(document: doc, field: 'notes_tsim')
    assert_includes result, '<span class="metadata-paragraph">Single note entry.</span>'
  end

  test 'formats multiple notes on separate lines with metadata-paragraph spans' do
    doc = SolrDocument.new(
      'id' => '123',
      'notes_tsim' => [
        'Archival Reference/Référence Archivistique: RG 30',
        'MIKAN:179735',
        'Reels/Bobines: C-12507',
        'Text generated through OCR; some errors may be present.'
      ]
    )
    result = format_text(document: doc, field: 'notes_tsim')

    # Each note must be wrapped in its own metadata-paragraph span
    assert_includes result, '<span class="metadata-paragraph">Archival Reference/Référence Archivistique: RG 30</span>'
    assert_includes result, '<span class="metadata-paragraph">MIKAN:179735</span>'
    assert_includes result, '<span class="metadata-paragraph">Reels/Bobines: C-12507</span>'
    assert_includes result, '<span class="metadata-paragraph">Text generated through OCR; some errors may be present.</span>'

    # Spans must not be smashed together without separation
    refute_includes result, 'RG 30</span><span'
    assert_includes result, "</span>\n<span class=\"metadata-paragraph\">"
  end
end
