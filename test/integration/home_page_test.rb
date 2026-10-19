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
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?lang=en&q=genealogy+immigration+settlements&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?lang=en&q=indigenous+history+land+education&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Government+Publications+%7C+Publications+gouvernementales&q=&search_field=all_fields&lang=en"]', text: 'Browse'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?lang=en&q=military+history&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?lang=en&q=personal+papers&search_field=all_fields"]', text: 'Browse'
    assert_select '.home-explore-heritage span.home-split-card__cta', count: 0

    get root_path(lang: :fr)
    assert_response :success
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?lang=fr&q=genealogie+immigration+etablissements&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?lang=fr&q=histoire+autochtone+terres+education&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Government+Publications+%7C+Publications+gouvernementales&q=&search_field=all_fields&lang=fr"]', text: 'Parcourir'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?lang=fr&q=histoire+militaire&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage a.home-split-card__cta[href="https://heritage.example.test/catalogue?lang=fr&q=documents+personnels&search_field=all_fields"]', text: 'Parcourir'
    assert_select '.home-explore-heritage span.home-split-card__cta', count: 0
  end

  test 'renders enabled heritage browse and search buttons on about heritage page in english and french' do
    get about_heritage_path
    assert_response :success
    assert_select 'a.about-heritage-hero__cta[href="https://heritage.example.test/catalogue?lang=en"]', text: /Search the Héritage Collection/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?lang=en&q=genealogy+immigration+settlements&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?lang=en&q=indigenous+history+land+education&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Government+Publications+%7C+Publications+gouvernementales&q=&search_field=all_fields&lang=en"]', text: /Browse/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?lang=en&q=military+history&search_field=all_fields"]', text: /Browse/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?lang=en&q=personal+papers&search_field=all_fields"]', text: /Browse/
    assert_select 'button.about-heritage-browse', count: 0

    get about_heritage_path(lang: :fr)
    assert_response :success
    assert_select 'a.about-heritage-hero__cta[href="https://heritage.example.test/catalogue?lang=fr"]', text: /Rechercher dans la collection Héritage/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?lang=fr&q=genealogie+immigration+etablissements&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?lang=fr&q=histoire+autochtone+terres+education&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Government+Publications+%7C+Publications+gouvernementales&q=&search_field=all_fields&lang=fr"]', text: /Parcourir/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?lang=fr&q=histoire+militaire&search_field=all_fields"]', text: /Parcourir/
    assert_select 'a.about-heritage-browse[href="https://heritage.example.test/catalogue?lang=fr&q=documents+personnels&search_field=all_fields"]', text: /Parcourir/
    assert_select 'button.about-heritage-browse', count: 0
  end

  test 'renders enabled canadiana browse buttons on home page in english and french' do
    get root_path
    assert_response :success
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Monographs+%7C+Monographies&q=&search_field=all_fields&lang=en"]', text: 'Browse'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Serials+%7C+Publications+en+se%CC%81rie&q=&search_field=all_fields&lang=en"]', text: 'Browse'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Government+Publications+%7C+Publications+gouvernementales&q=&search_field=all_fields&lang=en"]', text: 'Browse'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Maps+%7C+Cartes&q=&search_field=all_fields&lang=en"]', text: 'Browse'

    get root_path(lang: :fr)
    assert_response :success
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Monographs+%7C+Monographies&q=&search_field=all_fields&lang=fr"]', text: 'Parcourir'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Serials+%7C+Publications+en+se%CC%81rie&q=&search_field=all_fields&lang=fr"]', text: 'Parcourir'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Government+Publications+%7C+Publications+gouvernementales&q=&search_field=all_fields&lang=fr"]', text: 'Parcourir'
    assert_select '.home-explore-canadiana a.home-split-card__cta[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Maps+%7C+Cartes&q=&search_field=all_fields&lang=fr"]', text: 'Parcourir'
  end

  test 'renders enabled canadiana browse and search buttons on about canadiana page in english and french' do
    get about_canadiana_path
    assert_response :success
    assert_select 'a.home-hero__cta[href="https://canadiana.example.test/catalogue?lang=en"]', text: /Search the Canadiana Collection/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Monographs+%7C+Monographies&q=&search_field=all_fields&lang=en"]', text: /Browse/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Serials+%7C+Publications+en+se%CC%81rie&q=&search_field=all_fields&lang=en"]', text: /Browse/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Government+Publications+%7C+Publications+gouvernementales&q=&search_field=all_fields&lang=en"]', text: /Browse/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Maps+%7C+Cartes&q=&search_field=all_fields&lang=en"]', text: /Browse/

    get about_canadiana_path(lang: :fr)
    assert_response :success
    assert_select 'a.home-hero__cta[href="https://canadiana.example.test/catalogue?lang=fr"]', text: /Rechercher dans la collection Canadiana/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Monographs+%7C+Monographies&q=&search_field=all_fields&lang=fr"]', text: /Parcourir/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Serials+%7C+Publications+en+se%CC%81rie&q=&search_field=all_fields&lang=fr"]', text: /Parcourir/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Government+Publications+%7C+Publications+gouvernementales&q=&search_field=all_fields&lang=fr"]', text: /Parcourir/
    assert_select 'a.about-canadiana-browse[href="https://canadiana.example.test/catalogue?f%5Bcollection_tsim_str%5D%5B%5D=Maps+%7C+Cartes&q=&search_field=all_fields&lang=fr"]', text: /Parcourir/
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
