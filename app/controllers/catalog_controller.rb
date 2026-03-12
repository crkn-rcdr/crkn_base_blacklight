# frozen_string_literal: true

# Blacklight controller that handles searches and document requests
class CatalogController < ApplicationController
  include Blacklight::Catalog
  include BlacklightRangeLimit::ControllerOverride
  include Blacklight::Marc::Catalog

  # Blacklight's track action is a redirect used for click tracking and may
  # be invoked without an authenticity token. Skip CSRF verification for it.
  skip_before_action :verify_authenticity_token, only: [:track]
  before_action :ensure_default_catalog_query, only: :index

  configure_blacklight do |config|
    # Use the standard select handler
    config.solr_path = 'select'

    # per-page options
    config.per_page = [10, 20, 50, 100]

    # result list title
    config.index.title_field = 'full_title_tsim'

    # result list tools
    config.add_results_document_tool(:bookmark, component: Blacklight::Document::BookmarkComponent, if: :render_bookmarks_control?)
    config.add_results_collection_tool(:sort_widget)
    config.add_results_collection_tool(:per_page_widget)
    config.add_results_collection_tool(:view_type_group)
    config.add_show_tools_partial(:citation)

    # ----- FACETS -----

    # Publication year (range)
    config.add_facet_field 'pub_date_ssim',
                           label: ->(_c) { I18n.t('blacklight.metadata.date_range.label') },
                           range: {
                             num_segments: 10,
                             segments: true,
                             maxlength: 4,
                             assumed_boundaries: [1300, Time.now.year + 2],
                             chart_js: false
                           }

    # Standard facets (using *_str copies for docValues-backed facets)
    config.add_facet_field 'language_ssim_str',
                           label: ->(_c) { I18n.t('blacklight.metadata.language.label') },
                           sort: 'index', limit: 8, suggest: true, index_range: true
    config.add_facet_field 'depositor_tsim_str',
                           label: ->(_c) { I18n.t('blacklight.metadata.depositor.label') },
                           sort: 'count', limit: 8, suggest: true, index_range: true
    config.add_facet_field 'subject_ssim_str',
                           label: ->(_c) { I18n.t('blacklight.metadata.subject.label') },
                           sort: 'count', limit: 8, suggest: true, index_range: true
    config.add_facet_field 'author_ssm_str',
                           label: ->(_c) { I18n.t('blacklight.metadata.creator.label') },
                           sort: 'count', limit: 8, suggest: true, index_range: true

    # Materials facet (English values from 999$e)
    #config.add_facet_field 'materials_ssim_en',
    #                       label: 'Materials',
    #                       sort: 'count', limit: 8, suggest: true, index_range: true

    # Hierarchical Collections facet (uses slash-delimited paths in collectionen_path / collectionfr_path)
    config.add_facet_field 'collectionen_path',
      label:  ->(_c) { I18n.t('blacklight.metadata.collection.label') },
      component: Blacklight::Hierarchy::FacetFieldListComponent,
      if: ->(context, _config, _facet = nil) { CatalogController.language_code_for(context) != 'fr' }
    config.add_facet_field 'collectionfr_path',
      label:  ->(_c) { I18n.t('blacklight.metadata.collection.label') },
      component: Blacklight::Hierarchy::FacetFieldListComponent,
      if: ->(context, _config, _facet = nil) { CatalogController.language_code_for(context) == 'fr' }
    # Tell blacklight-hierarchy how to parse the field into a tree (use slash delimiter)
    # key is the field name prefix before the last underscore
    config.facet_display = {
      hierarchy: {
        'collectionen' => [['path'], '/'],
        'collectionfr' => [['path'], '/']
      }
    }
    config.add_facet_field 'serial_title_str',
                           label: ->(_c) { I18n.t('blacklight.metadata.serial_title.label') },
                           sort: 'count', limit: 8, suggest: true, index_range: true
    
    config.add_facet_field 'is_issue_str',
                           label: ->(_c) { I18n.t('blacklight.metadata.issue_msg.label') },
                           sort: 'count', limit: 8, suggest: true, index_range: true
    config.add_facet_field 'is_serial_str',
                           label: ->(_c) { I18n.t('blacklight.metadata.serial_msg.label') },
                           sort: 'count', limit: 8, suggest: true, index_range: true

    # Send facet field list to Solr
    config.add_facet_fields_to_solr_request!

    # ----- INDEX (search results) FIELDS -----
    config.add_index_field 'format', label: 'Format', helper_method: :format_icon
    config.add_index_field 'title_ssm',  label: ->(_f, _c) { I18n.t('blacklight.metadata.title.label') }, helper_method: :format_text
    config.add_index_field 'author_ssm', label: ->(_f, _c) { I18n.t('blacklight.metadata.creator.label') }, helper_method: :format_facet
    config.add_index_field 'published_ssm', label: ->(_f, _c) { I18n.t('blacklight.metadata.published.label') }
    config.add_index_field 'pub_date_ssim', label: ->(_f, _c) { I18n.t('blacklight.metadata.date.label') }
    config.add_index_field 'subject_ssim', label: ->(_f, _c) { I18n.t('blacklight.metadata.subject.label') }, helper_method: :format_facet
    config.add_index_field 'depositor_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.depositor.label') }, helper_method: :format_facet
    config.add_index_field 'language_ssim', label: ->(_f, _c) { I18n.t('blacklight.metadata.language.label') }, helper_method: :format_facet
    config.add_index_field 'notes_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.notes.label') }, helper_method: :format_text
    config.add_index_field 'original_version_note_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.original_version_note.label') }, helper_method: :format_text
    config.add_index_field 'access_note_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.access_note.label') }, helper_method: :format_text
    config.add_index_field 'ark', label: ->(_f, _c) { I18n.t('blacklight.metadata.persistent_url.label') }, helper_method: :value_link
    config.add_index_field 'date_added', label: ->(_f, _c) { I18n.t('blacklight.metadata.date_added.label') }, helper_method: :format_date

    # ----- SHOW FIELDS -----
    #config.add_show_field 'title_ssm',  label: ->(_f, _c) { I18n.t('blacklight.metadata.title.label') }, helper_method: :format_text
    #config.add_show_field 'subtitle_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.subtitle.label') }, helper_method: :format_text
    #config.add_show_field 'title_addl_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.other_titles.label') }, helper_method: :format_text
    config.add_show_field 'rights_stat_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.right_statements.label') }, helper_method: :format_text
    config.add_show_field 'ark', label: ->(_f, _c) { I18n.t('blacklight.metadata.persistent_url.label') }, helper_method: :value_link
    config.add_show_field 'depositor_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.depositor.label') }, helper_method: :format_facet
    config.add_show_field 'language_ssim', label: ->(_f, _c) { I18n.t('blacklight.metadata.language.label') }, helper_method: :format_facet
    config.add_show_field 'author_ssm', label: ->(_f, _c) { I18n.t('blacklight.metadata.creator.label') }, helper_method: :format_facet
    config.add_show_field 'published_ssm', label: ->(_f, _c) { I18n.t('blacklight.metadata.published.label') }
    config.add_show_field 'pub_date_ssim', label: ->(_f, _c) { I18n.t('blacklight.metadata.date.label') }
    config.add_show_field 'subject_ssim', label: ->(_f, _c) { I18n.t('blacklight.metadata.subject.label') }, helper_method: :format_facet
    config.add_show_field 'notes_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.notes.label') }, helper_method: :format_text
    config.add_show_field 'original_version_note_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.original_version_note.label') }, helper_method: :format_text
    #config.add_show_field 'access_note_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.access_note.label') }, helper_method: :format_text
    #config.add_show_field 'source_of_description_tsim', label: ->(_f, _c) { I18n.t('blacklight.metadata.source_of_description.label') }, helper_method: :format_text
    config.add_show_field 'date_added', label: ->(_f, _c) { I18n.t('blacklight.metadata.date_added.label') }, helper_method: :format_date

    # ----- SEARCH FIELDS -----
    config.add_search_field 'all_fields', label: ->(_c) { I18n.t('blacklight.metadata.all_fields.label') }

    config.add_search_field('full_title_tsim') do |field|
      field.solr_parameters = { qf: 'full_title_tsim', pf: 'full_title_tsim' }
      field.label = ->(_c) { I18n.t('blacklight.metadata.title.label') }
    end

    config.add_search_field('author_tsim') do |field|
      field.solr_parameters = { qf: 'author_tsim', pf: 'author_tsim' }
      field.label = ->(_c) { I18n.t('blacklight.metadata.creator.label') }
    end

    config.add_search_field('subject_tsim') do |field|
      field.qt = 'search'
      field.solr_parameters = { qf: 'subject_tsim', pf: 'subject_tsim' }
      field.label = ->(_c) { I18n.t('blacklight.metadata.subject.label') }
    end

    config.add_search_field('tx_gen') do |field|
      field.solr_parameters = { qf: 'tx_gen', pf: 'tx_gen' }
      field.label = ->(_c) { I18n.t('blacklight.metadata.fulltx.label') }
    end

    # ----- SORTS -----
    config.add_sort_field 'relevance',        sort: 'score desc', label: ->(_c) { I18n.t('blacklight.sort.relevance.label') }
    config.add_sort_field 'year-desc',        sort: 'pub_date_ssim desc',              label: ->(_c) { I18n.t('blacklight.sort.year_desc.label') }
    config.add_sort_field 'year-asc',         sort: 'pub_date_ssim asc',               label: ->(_c) { I18n.t('blacklight.sort.year_asc.label') }
    config.add_sort_field 'date-added-desc',  sort: 'date_added desc',               label: ->(_c) { I18n.t('blacklight.sort.date_added_desc.label') }
    config.add_sort_field 'date-added-asc',   sort: 'date_added asc',                label: ->(_c) { I18n.t('blacklight.sort.date_added_asc.label') }

    # Autocomplete / suggest
    config.spell_max = 5
    config.autocomplete_enabled = true
    config.autocomplete_path = 'suggest'

    # keep params tidy
    config.filter_search_state_fields = true
  end

  private def ensure_default_catalog_query
    return unless request.get?
    return unless request.format.html?

    query_params = request.query_parameters.deep_dup
    defaults_added = false

    if query_params['search_field'].blank?
      query_params['search_field'] = 'all_fields'
      defaults_added = true
    end

    unless query_params.key?('q')
      query_params['q'] = ''
      defaults_added = true
    end

    redirect_to search_catalog_path(query_params) if defaults_added
  end

  def self.language_code_for(context)
    lang =
      if context.respond_to?(:content_lang) && context.content_lang.present?
        context.content_lang
      elsif context.respond_to?(:params) && context.params[:lang].present?
        context.params[:lang]
      else
        I18n.locale.to_s
      end

    lang.to_s.downcase
  end
end










