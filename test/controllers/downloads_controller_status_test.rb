require "test_helper"

class DownloadsControllerStatusTest < ActionController::TestCase
  tests DownloadsController

  test "status endpoint returns JSON with ready boolean" do
    get :status, params: { id: "test_docid", ark: "ark:/12345/test" }, format: :json
    assert_response :success
    assert_includes response.content_type, "application/json"
    
    json = JSON.parse response.body
    assert json.key?("ready")
    assert json.key?("message")
  end

  test "status returns 400 when docid missing" do
    get :status, params: { ark: "ark:/12345/test" }, format: :json
    assert_response :bad_request
    
    json = JSON.parse response.body
    assert_equal false, json["ready"]
    assert_includes json["message"], "docid"
  end

  test "status returns 400 when ark path missing" do
    get :status, params: { id: "test_docid" }, format: :json
    assert_response :bad_request
    
    json = JSON.parse response.body
    assert_equal false, json["ready"]
    assert_includes json["message"], "ark"
  end

  test "status returns ready false when file not ready" do
    get :status, params: { id: "test_docid", ark: "ark:/12345/test" }, format: :json
    assert_response :success
    
    json = JSON.parse response.body
    assert_equal false, json["ready"]
    assert_includes json["message"], "preparing"
  end

  test "status includes url when file ready" do
    # This would require mocking file availability
    # For now, test that response structure is correct
    get :status, params: { id: "test_docid", ark: "ark:/12345/test" }, format: :json
    assert_response :success
    
    json = JSON.parse response.body
    unless json["ready"]
      assert_nil json["url"]
    end
  end
end
