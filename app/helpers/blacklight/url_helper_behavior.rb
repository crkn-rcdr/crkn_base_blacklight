# frozen_string_literal: true

require 'uri'

##
# URL helper methods
module Blacklight::UrlHelperBehavior
  # Uses the catalog_path route to create a link to the show page for an item.
  # catalog_path accepts a hash. The solr query params are stored in the session,
  # so we only need the +counter+ param here. We also need to know if we are viewing to document as part of search results.
  # TODO: move this to the IndexPresenter
  # @param doc [SolrDocument] the document
  # @param field_or_opts [Hash, String] either a string to render as the link text or options
  # @param opts [Hash] the options to create the link with
  # @option opts [Number] :counter (nil) the count to set in the session (for paging through a query result)
  # @example Passing in an image
  #   link_to_document(doc, '<img src="thumbnail.png">', counter: 3) #=> "<a href=\"catalog/123\" data-context-href=\"/catalog/123/track?counter=3&search_id=999\"><img src="thumbnail.png"></a>
  # @example With the default document link field
  #   link_to_document(doc, counter: 3) #=> "<a href=\"catalog/123\" data-context-href=\"/catalog/123/track?counter=3&search_id=999\">My Title</a>
  def link_to_document(doc, field_or_opts = nil, opts = { counter: nil })
    label = case field_or_opts
            when NilClass
              document_presenter(doc).heading
            when Hash
              opts = field_or_opts
              document_presenter(doc).heading
            else # String
              field_or_opts
            end

    # Build href explicitly so it always carries q/lang and search_id if available
    doc_params = {
      lang: params[:lang].presence,
      q: params[:q].presence
    }
    if respond_to?(:current_search_session) && current_search_session&.id.present?
      doc_params[:search_id] = current_search_session.id
    elsif respond_to?(:search_session) && search_session['id'].present?
      doc_params[:search_id] = search_session['id']
    end

    href = solr_document_path(doc, doc_params.compact)

    link_to label, href, document_link_params(doc, opts)
  end

  # @private
  # Extend the default options for document links by ensuring the
  # tracking URL (data-context-href) also carries the current query (q)
  # so analytics reflect the originating search term.
  def document_link_params(doc, opts)
    params_hash = session_tracking_params(doc, opts[:counter]).deep_merge(opts.except(:label, :counter))

    if params[:q].present? && params_hash.dig(:data, :context_href).present?
      href = params_hash[:data][:context_href]
      sep = href.include?('?') ? '&' : '?'
      has_q = begin
        URI.parse(href).query.to_s.include?('q=')
      rescue URI::InvalidURIError
        href.include?('q=')
      end
      unless has_q
        params_hash[:data][:context_href] = href + sep + "q=#{ERB::Util.url_encode(params[:q])}"
      end
    end

    params_hash
  end
  private :document_link_params

  ##
  # Attributes for a link that gives a URL we can use to track clicks for the current search session.
  # We disable turbo prefetch (InstantClick), because since we replace the link with a form, it's just wasted.
  # @param [SolrDocument] document
  # @param [Integer] counter
  # @example
  #   session_tracking_params(SolrDocument.new(id: 123), 7)
  #   => { data: { context_href: '/catalog/123/track?counter=7&search_id=999' } }
  def session_tracking_params document, counter, per_page: search_session['per_page'], search_id: current_search_session&.id
    path_params = { per_page: params.fetch(:per_page, per_page), counter: counter, search_id: search_id }
    if blacklight_config.track_search_session.storage == 'server'
      path_params[:document_id] = document&.id
      path_params[:search_id] = search_id
    end
    path = session_tracking_path(document, path_params)
    return {} if path.nil?

    context_method = blacklight_config.track_search_session.storage == 'client' ? 'get' : 'post'
    { data: { context_href: path, context_method: context_method, turbo_prefetch: false } }
  end

  ##
  # Get the URL for tracking search sessions across pages using polymorphic routing
  def session_tracking_path document, params = {}
    return if document.nil? || !blacklight_config.track_search_session.storage

    if main_app.respond_to?(controller_tracking_method)
      return main_app.public_send(controller_tracking_method, params.merge(id: document))
    end

    raise "Unable to find #{controller_tracking_method} route helper. " \
          "Did you add `concerns :searchable` routing mixin to your `config/routes.rb`?"
  end

  def controller_tracking_method
    return blacklight_config.track_search_session.url_helper if blacklight_config.track_search_session.url_helper

    "track_#{controller_name}_path"
  end

  #
  # link based helpers ->
  #

  # Constructs the URL to return to the catalog search results with all search filters,
  # facets, search fields, and pagination preserved from the active search session.
  def back_to_search_url
    query_params = if respond_to?(:current_search_session) && current_search_session.try(:query_params).present?
                     search_state.reset(current_search_session.query_params).to_hash
                   else
                     request.query_parameters.except('pageNum', 'id').to_h
                   end

    query_params = query_params.with_indifferent_access

    if respond_to?(:search_session) && search_session['counter']
      per_page = (search_session['per_page'] || blacklight_config.default_per_page).to_i
      counter = search_session['counter'].to_i

      query_params[:per_page] = per_page unless search_session['per_page'].to_i == blacklight_config.default_per_page
      query_params[:page] = ((counter - 1) / per_page) + 1
    end

    query_params.delete(:id)
    query_params.delete(:pageNum)
    query_params.delete(:utf8)
    query_params.delete(:commit)

    lang = respond_to?(:current_ui_language_param) ? current_ui_language_param : (params[:lang].presence || I18n.locale.to_s)
    query_params[:lang] ||= lang if lang.present?

    clean_params = query_params.except(:controller, :action, :only_path)
    if clean_params.except(:lang).empty? && clean_params[:q].blank?
      search_action_path(only_path: true, lang: query_params[:lang])
    else
      search_action_path(clean_params.merge(only_path: true))
    end
  end

  # Create a link back to the index screen, keeping the user's facet, query and paging choices intact by using session.
  # @example
  #   link_back_to_catalog(label: 'Back to Search')
  #   link_back_to_catalog(label: 'Back to Search', route_set: my_engine)
  def link_back_to_catalog(opts = { label: nil })
    scope = opts.delete(:route_set) || self
    link_url = back_to_search_url
    label = opts.delete(:label)

    if link_url =~ /bookmarks/
      label ||= t('blacklight.back_to_bookmarks')
    end

    label ||= t('blacklight.back_to_search')

    link_to label, link_url, opts
  end

  # Use in e.g. the search history display, where we want something more like text instead of the normal constraints
  def link_to_previous_search(params)
    search_state = controller.search_state_class.new(params, blacklight_config, self)
    link_to(render(Blacklight::ConstraintsComponent.for_search_history(search_state: search_state, classes: 'clearfix constraints-container mb-0')), search_action_path(params))
  end
end
