# frozen_string_literal: true

class CheckboxFacetComponent < Blacklight::Component
  FacetRow = Struct.new(:value, :label, :hits, :selected, keyword_init: true)

  def initialize(facet_field:, layout: nil)
    @facet_field = facet_field
    @layout = layout == false ? Blacklight::FacetFieldNoLayoutComponent : CheckboxFacetLayoutComponent
  end

  def render?
    return true if @facet_field.in_modal?

    rows.any?
  end

  def rows
    @rows ||= begin
      rendered_rows = facet_items.map do |item|
        presenter = presenter_for(item)
        FacetRow.new(
          value: presenter.value,
          label: presenter.label,
          hits: presenter.hits,
          selected: selected_value?(presenter.value)
        )
      end

      selected_rows_not_in_results(rendered_rows) + rendered_rows
    end
  end

  def hidden_fields
    helpers.safe_join(hidden_field_tags)
  end

  def form_action
    helpers.search_catalog_path
  end

  def clear_path
    params = preserved_params.deep_dup
    %w[f f_inclusive checkbox_facet_selections].each do |filter_param|
      params[filter_param]&.delete(facet_key)
      params.delete(filter_param) if params[filter_param].blank?
    end
    helpers.search_action_path(params)
  end

  def more_path
    return if @facet_field.in_modal?

    helpers.search_facet_path(modal_params.merge(id: facet_key))
  end

  def modal_pagination
    return unless @facet_field.in_modal?

    helpers.render(Blacklight::FacetFieldPaginationComponent.new(facet_field: @facet_field))
  end

  def checkbox_id(index)
    "facet-checkbox-#{facet_key.parameterize}-#{index}"
  end

  def selected_values
    @selected_values ||= begin
      req_params = helpers.respond_to?(:params) ? helpers.params.to_unsafe_h : {}
      state_params = begin
        if @facet_field.respond_to?(:search_state) && @facet_field.search_state.respond_to?(:params)
          @facet_field.search_state.params
        else
          {}
        end
      rescue StandardError
        {}
      end

      values = []
      [req_params, state_params].compact.each do |p|
        next unless p.is_a?(Hash) || p.respond_to?(:to_unsafe_h)
        hash = p.respond_to?(:to_unsafe_h) ? p.to_unsafe_h : p
        values.concat(Array(nested_param_value(hash, 'f')))
        values.concat(Array(nested_param_value(hash, 'f_inclusive')))
        values.concat(Array(nested_param_value(hash, 'checkbox_facet_selections')))
      end
      values.flatten.compact_blank.map(&:to_s).uniq
    end
  end

  private

  def facet_items
    @facet_field.paginator&.items || []
  end

  def selected_rows_not_in_results(rendered_rows)
    return [] if @facet_field.in_modal?

    rendered_values = rendered_rows.map { |row| row.value.to_s }

    selected_values.reject { |value| rendered_values.include?(value) }.map do |value|
      FacetRow.new(
        value: value,
        label: presenter_for(value).label,
        selected: true
      )
    end
  end

  def selected_value?(value)
    selected_values.include?(value.to_s)
  end

  def presenter_for(item)
    Blacklight::FacetItemPresenter.new(
      item,
      @facet_field.facet_field,
      helpers,
      facet_key,
      @facet_field.search_state
    )
  end

  def hidden_field_tags
    form_preserved_params.flat_map do |name, value|
      hidden_fields_for(name, value)
    end
  end

  def hidden_fields_for(name, value)
    case value
    when Hash
      value.flat_map { |child_name, child_value| hidden_fields_for("#{name}[#{child_name}]", child_value) }
    when Array
      value.flat_map { |child_value| hidden_fields_for("#{name}[]", child_value) }
    else
      [helpers.hidden_field_tag(name, value)]
    end
  end

  def preserved_params
    @preserved_params ||= begin
      params = helpers.params.to_unsafe_h.deep_dup
      params.except!('action', 'authenticity_token', 'button', 'commit', 'controller', 'id', 'only_values', 'page', 'utf8')
      params
    end
  end

  def form_preserved_params
    params = preserved_params.deep_dup
    %w[f f_inclusive checkbox_facet_selections].each do |filter_param|
      params[filter_param]&.delete(facet_key)
      params.delete(filter_param) if params[filter_param].blank?
    end
    params
  end

  def modal_params
    params = preserved_params.deep_dup
    return params if selected_values.blank?

    params['f_inclusive'] ||= {}
    params['f_inclusive'][facet_key] = selected_values
    params['checkbox_facet_selections'] ||= {}
    params['checkbox_facet_selections'][facet_key] = selected_values
    params
  end

  def nested_param_value(params, name)
    return unless params.respond_to?(:[])

    values = params[name] || params[name.to_s] || params[name.to_sym]
    return unless values.respond_to?(:[])

    values[facet_key] || values[facet_key.to_s] || values[facet_key.to_sym]
  end

  def facet_key
    @facet_key ||= begin
      key = if @facet_field.respond_to?(:key) && @facet_field.key.present?
              @facet_field.key
            elsif @facet_field.respond_to?(:name) && @facet_field.name.present?
              @facet_field.name
            elsif @facet_field.respond_to?(:facet_field) && @facet_field.facet_field.respond_to?(:key)
              @facet_field.facet_field.key
            end
      key&.to_s || helpers.params[:id]&.to_s || ''
    end
  end
end
