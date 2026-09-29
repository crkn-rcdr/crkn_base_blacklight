require 'test_helper'

class HomePageTest < ActionDispatch::IntegrationTest
  setup do
    @old_canadiana_catalogue_url = Rails.configuration.x.canadiana_catalogue_url
    @old_heritage_catalogue_url = Rails.configuration.x.heritage_catalogue_url
    Rails.configuration.x.canadiana_catalogue_url = 'https://canadiana.example.test/catalogue'
    Rails.configuration.x.heritage_catalogue_url = 'https://heritage.example.test/catalogue'
  end

  teardown do
    Rails.configuration.x.canadiana_catalogue_url = @old_canadiana_catalogue_url
    Rails.configuration.x.heritage_catalogue_url = @old_heritage_catalogue_url
  end

  test 'uses configured collection catalogue endpoints for home searches' do
    get root_path

    assert_response :success
    assert_select 'form.home-canadiana-search__form[action="https://canadiana.example.test/catalogue"]'
    assert_select 'form.home-heritage-search__form[action="https://heritage.example.test/catalogue"]'
  end
end
