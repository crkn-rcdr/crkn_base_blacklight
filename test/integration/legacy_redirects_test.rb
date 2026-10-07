require 'test_helper'

class LegacyRedirectsTest < ActionDispatch::IntegrationTest
  test 'redirects /view/:id/:pageNum to /catalogue/:id?pageNum=:pageNum' do
    get '/view/sfu.00001_19180302/1'
    assert_response :moved_permanently
    assert_redirected_to '/catalogue/sfu.00001_19180302?pageNum=1'
  end

  test 'redirects /view/:id without pageNum to /catalogue/:id' do
    get '/view/sfu.00001'
    assert_response :moved_permanently
    assert_redirected_to '/catalogue/sfu.00001'
  end

  test 'preserves existing query parameters on /view/:id/:pageNum' do
    get '/view/sfu.00001_19180302/5?locale=fr'
    assert_response :moved_permanently
    assert_redirected_to '/catalogue/sfu.00001_19180302?locale=fr&pageNum=5'
  end

  test 'redirects /view to /catalogue' do
    get '/view'
    assert_response :moved_permanently
    assert_redirected_to '/catalogue'
  end
end
