require 'test_helper'

class AppliedParamsStylesTest < ActionDispatch::IntegrationTest
  test 'compiled application stylesheet hides appliedParams and pagination widgets when parent has #document' do
    css = Rails.application.assets['application.css'].to_s

    # Verify relational :has(#document) and show-document hide rules are compiled into CSS
    assert_match(/:has\(>\s*#document\)\s*>\s*#appliedParams/, css)
    assert_match(/:has\(>\s*#document\)\s*>\s*\.pagination-search-widgets/, css)
    assert_match(/#appliedParams:has\(\s*~\s*#document\)/, css)
    assert_match(/\.show-document\s*>\s*#appliedParams/, css)
    assert_match(/\.show-document\s*>\s*\.pagination-search-widgets/, css)

    # Verify display: none !important is applied to hide appliedParams on document parent
    assert_match(/#appliedParams[^}]*\{[^}]*display:\s*none\s*!important/m, css)
  end

  test 'search hero applied params styling is preserved on search index page' do
    css = Rails.application.assets['application.css'].to_s

    # Ensure search results hero structure remains styled and not unconditionally hidden
    assert_match(/\.blacklight-catalog-index\s+\.catalog-search-hero__applied\s+#appliedParams/, css)
  end

  test 'SCSS source files define relational parent hiding rules' do
    canadiana_scss = File.read(Rails.root.join('app/assets/stylesheets/base/canadiana.scss'))
    blacklight_scss = File.read(Rails.root.join('app/assets/stylesheets/blacklight.scss'))

    [canadiana_scss, blacklight_scss].each do |content|
      assert_includes content, ':has(> #document) > #appliedParams'
      assert_includes content, ':has(> #document) > .pagination-search-widgets'
      assert_includes content, '#appliedParams:has(~ #document)'
      assert_includes content, '.show-document > #appliedParams'
      assert_includes content, 'display: none !important;'
    end
  end
end

