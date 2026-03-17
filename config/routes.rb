Rails.application.routes.draw do
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  mount Blacklight::Engine => '/'
  root to: "pages#home"
  # Simple about pages for collections
  get '/compare-collections', to: 'pages#compare_collections', as: :compare_collections
  get '/about/monographs', to: 'pages#about_monographs'
  get '/about/serials', to: 'pages#about_serials'
  get '/about/government-publications', to: 'pages#about_govpubs'
  get '/about/maps', to: 'pages#about_maps'
  get '/what-is-iiif', to: 'pages#what_is_iiif', as: :what_is_iiif
  # Allow slashes inside :ark (e.g., ark:/69429/m0k35m90313z)
  get '/dl/:id/*ark', to: 'downloads#index', constraints: { id: /[0-z\.]+/ }, format: false
  #root to: "catalog#index"
  concern :marc_viewable, Blacklight::Marc::Routes::MarcViewable.new
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [], as: 'catalog', path: '/catalog', controller: 'catalog', id: /[^\/]+/ do
    concerns :searchable
    concerns :range_searchable

  end

  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog', id: /[^\/]+/  do
    concerns [:exportable, :marc_viewable]
  end

  resources :bookmarks, only: [:index, :update, :create, :destroy] do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
