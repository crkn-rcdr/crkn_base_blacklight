require "test_helper"
require "rights_statement_labeler"

class RightsStatementLabelerTest < ActiveSupport::TestCase
  test "correctly localizes distinct in copyright statements" do
    assert_equal "In Copyright - Non-Commercial Use Permitted",
                 RightsStatementLabeler.localized_label_for("In Copyright - Non-Commercial Use Permitted", :en)
    assert_equal "Sous droit d'auteur - Utilisation non commerciale permise",
                 RightsStatementLabeler.localized_label_for("In Copyright - Non-Commercial Use Permitted", :fr)

    assert_equal "In Copyright - Educational Use Permitted",
                 RightsStatementLabeler.localized_label_for("In Copyright - Educational Use Permitted", :en)
    assert_equal "Sous droit d'auteur - Utilisation éducative permise",
                 RightsStatementLabeler.localized_label_for("In Copyright - Educational Use Permitted", :fr)

    assert_equal "In Copyright",
                 RightsStatementLabeler.localized_label_for("In Copyright", :en)
    assert_equal "Protégé par le droit d'auteur",
                 RightsStatementLabeler.localized_label_for("In Copyright", :fr)
  end

  test "resolves canonical url for specific in copyright statements" do
    assert_equal "https://rightsstatements.org/page/InC-NC/1.0/?language=en",
                 RightsStatementLabeler.canonical_url_for_label("In Copyright - Non-Commercial Use Permitted", :en)
    assert_equal "https://rightsstatements.org/page/InC-EDU/1.0/?language=en",
                 RightsStatementLabeler.canonical_url_for_label("In Copyright - Educational Use Permitted", :en)
    assert_equal "https://rightsstatements.org/page/InC/1.0/?language=en",
                 RightsStatementLabeler.canonical_url_for_label("In Copyright", :en)
  end
end

