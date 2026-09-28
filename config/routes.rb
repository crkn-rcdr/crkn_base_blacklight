Rails.application.routes.draw do
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  get '/catalogue/:id.txt', to: 'catalog#tx_gen', as: :catalog_tx_gen, constraints: { id: /[^\/]+/ }, defaults: { format: :txt }
  get '/catalog/:id.txt', to: 'catalog#tx_gen', constraints: { id: /[^\/]+/ }, defaults: { format: :txt }
  mount Blacklight::Engine => '/'
  root to: "pages#home"
  # Simple about pages for collections
  get '/compare-collections', to: 'pages#compare_collections', as: :compare_collections
  get '/about/canadiana', to: 'pages#about_canadiana', as: :about_canadiana
  get '/about/heritage', to: 'pages#about_heritage', as: :about_heritage
  get '/api-access', to: 'pages#api_access', as: :api_access
  get '/what-is-iiif', to: 'pages#what_is_iiif', as: :what_is_iiif
  get '/citation-guide', to: 'pages#citation_guide', as: :citation_guide
  get '/navigating-collections', to: 'pages#navigating_collections', as: :navigating_collections
  get '/contact-us', to: 'pages#contact_us', as: :contact_us_page
  get '/system-status', to: 'pages#system_status', as: :system_status
  get '/sitemap', to: 'pages#sitemap', as: :sitemap
  get '/terms-of-service', to: 'pages#terms_of_service', as: :terms_of_service
  # Allow slashes inside :ark (e.g., ark:/69429/m0k35m90313z)
  get '/dl/:id/*ark', to: 'downloads#index', constraints: { id: /[0-z\.]+/ }, format: false
  #root to: "catalog#index"
  concern :marc_viewable, Blacklight::Marc::Routes::MarcViewable.new
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [], as: 'catalog', path: '/catalogue', controller: 'catalog', id: /[^\/]+/ do
    concerns :searchable
    concerns :range_searchable
  end

  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalogue', controller: 'catalog', id: /[^\/]+/  do
    concerns [:exportable, :marc_viewable]
  end

  # Legacy/redirect routes for /catalog -> /catalogue
  get '/catalog', to: redirect(->(_params, req) {
    req.query_string.present? ? "/catalogue?#{req.query_string}" : "/catalogue"
  })
  get '/catalog/:id', to: redirect(->(params, req) {
    req.query_string.present? ? "/catalogue/#{params[:id]}?#{req.query_string}" : "/catalogue/#{params[:id]}"
  }), constraints: { id: /[^\/]+/ }
  get '/catalog/:id/citation', to: redirect(->(params, req) {
    req.query_string.present? ? "/catalogue/#{params[:id]}/citation?#{req.query_string}" : "/catalogue/#{params[:id]}/citation"
  }), constraints: { id: /[^\/]+/ }
  get '/catalog/:id/librarian_view', to: redirect(->(params, req) {
    req.query_string.present? ? "/catalogue/#{params[:id]}/librarian_view?#{req.query_string}" : "/catalogue/#{params[:id]}/librarian_view"
  }), constraints: { id: /[^\/]+/ }
  get '/catalog/facet/:id', to: redirect(->(params, req) {
    req.query_string.present? ? "/catalogue/facet/#{params[:id]}?#{req.query_string}" : "/catalogue/facet/#{params[:id]}"
  })
  get '/catalog/facet_suggest/:id(/:query_fragment)', to: 'catalog#facet', defaults: { only_values: true }, constraints: { id: /[^\/]+/ }
  get '/catalogue/facet_suggest/:id(/:query_fragment)', to: 'catalog#facet', defaults: { only_values: true }, constraints: { id: /[^\/]+/ }

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
