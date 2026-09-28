# frozen_string_literal: true

class CheckboxFacetLayoutComponent < Blacklight::Component
  renders_one :label
  renders_one :body

  def initialize(facet_field:)
    @facet_field = facet_field
  end

  def html_id
    "facet-#{@facet_field.key.parameterize}"
  end

  def header_html_id
    "#{html_id}-header"
  end
end
