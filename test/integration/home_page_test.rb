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
    assert_select 'button.home-heritage-search__submit:not([disabled])', text: 'Search'
  end

  test 'renders new heritage collection content link with date-added-desc sort' do
    get root_path

    assert_response :success
    assert_select 'a.dropdown-item--heritage[href="https://heritage.example.test/catalogue?lang=en&q=&search_field=all_fields&sort=date-added-desc"]', text: 'New Héritage Collection Content'
  end

  test 'renders enabled heritage browse buttons on home page in english and french' do
    get root_path
    assert_response :success
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Genealogy+Materials&lang=en&q=&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Indigenous+Peoples&lang=en&q=&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Government+Records&lang=en&q=&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Military+History&lang=en&q=&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=People+and+Organizations&lang=en&q=&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage span.home-split-card__cta', count: 0

    get root_path(lang: :fr)
    assert_response :success
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Documents+g%C3%A9n%C3%A9alogiques&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Peuples+autochtones&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Services+gouvernementaux&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Histoire+militaire&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Personnalit%C3%A9s+canadiennes&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage span.home-split-card__cta', count: 0
  end

  test 'renders enabled heritage browse and search buttons on about heritage page in english and french' do
    get about_heritage_path
    assert_response :success
    assert_select 'a.about-heritage-hero__cta[href="https://heritage.example.test/catalogue?lang=en"]', text: /Search the Héritage Collection/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Genealogy+Materials&lang=en&q=&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Indigenous+Peoples&lang=en&q=&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Government+Records&lang=en&q=&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Military+History&lang=en&q=&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=People+and+Organizations&lang=en&q=&search_field=all_fields"]', text: /Browse/
    assert_select 'button.about-heritage-browse', count: 0

    get about_heritage_path(lang: :fr)
    assert_response :success
    assert_select 'a.about-heritage-hero__cta[href="https://heritage.example.test/catalogue?lang=fr"]', text: /Rechercher dans la collection Héritage/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Documents+g%C3%A9n%C3%A9alogiques&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Peuples+autochtones&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Services+gouvernementaux&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Histoire+militaire&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Personnalit%C3%A9s+canadiennes&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
    assert_select 'button.about-heritage-browse', count: 0
  end

  test 'renders enabled canadiana browse buttons on home page in english and french' do
    get root_path
    assert_response :success
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Monographs&lang=en&q=&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Serials&lang=en&q=&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Government+Publications&lang=en&q=&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Maps&lang=en&q=&search_field=all_fields"]', text: 'Browse'

    get root_path(lang: :fr)
    assert_response :success
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Monographies&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Publications+en+se%CC%81rie&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Publications+gouvernementales&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Cartes&lang=fr&q=&search_field=all_fields"]', text: 'Parcourir'
  end

  test 'renders enabled canadiana browse and search buttons on about canadiana page in english and french' do
    get about_canadiana_path
    assert_response :success
    assert_select 'a.home-hero__cta[href="https://canadiana.example.test/catalogue?lang=en"]', text: /Search the Canadiana Collection/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Monographs&lang=en&q=&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Serials&lang=en&q=&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Government+Publications&lang=en&q=&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollectionen_path%5D%5B%5D=Maps&lang=en&q=&search_field=all_fields"]', text: /Browse/

    get about_canadiana_path(lang: :fr)
    assert_response :success
    assert_select 'a.home-hero__cta[href="https://canadiana.example.test/catalogue?lang=fr"]', text: /Rechercher dans la collection Canadiana/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Monographies&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Publications+en+se%CC%81rie&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Publications+gouvernementales&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollectionfr_path%5D%5B%5D=Cartes&lang=fr&q=&search_field=all_fields"]', text: /Parcourir/
  end

  test 'renders both canadiana and heritage catalogue links in sitemap in english and french' do
    get sitemap_path
    assert_response :success
    assert_select 'a[href="https://canadiana.example.test/catalogue?lang=en"]', text: 'Search the Canadiana Collection'
    assert_select 'a[href="https://heritage.example.test/catalogue?lang=en"]', text: 'Search the Héritage Collection'

    get sitemap_path(lang: :fr)
    assert_response :success
    assert_select 'a[href="https://canadiana.example.test/catalogue?lang=fr"]', text: 'Rechercher dans la collection Canadiana'
    assert_select 'a[href="https://heritage.example.test/catalogue?lang=fr"]', text: 'Rechercher dans la collection Héritage'
  end
end
