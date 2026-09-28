# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightRangeLimit::RangeLimitBuilder


  self.default_processor_chain += [
    :add_inclusive_facet_fq_to_solr,
    :tag_and_exclude_facets,
    :filter_individual_issues
  ]

  def add_inclusive_facet_fq_to_solr(solr_parameters)
    return unless solr_parameters

    inclusive_params = blacklight_params[:f_inclusive] || blacklight_params['f_inclusive']
    return unless inclusive_params.is_a?(Hash) || inclusive_params.respond_to?(:to_unsafe_h)

    inclusive_hash = inclusive_params.respond_to?(:to_unsafe_h) ? inclusive_params.to_unsafe_h : inclusive_params
    facet_configs = blacklight_config.facet_fields

    inclusive_hash.each do |field_key, values|
      clean_values = Array(values).compact_blank
      next if clean_values.empty?

      config = facet_configs[field_key] || facet_configs[field_key.to_s] || facet_configs[field_key.to_sym]
      solr_field = (config&.field || field_key).to_s
      tag = "tag_#{field_key.to_s.parameterize.underscore}"

      # Build OR filter query for multiple values of the same facet
      clause = clean_values.map do |val|
        escaped_val = val.to_s.gsub('"', '\\"')
        "#{solr_field}:\"#{escaped_val}\""
      end.join(' OR ')

      fq_str = "{!tag=#{tag}}(#{clause})"

      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << fq_str unless solr_parameters[:fq].include?(fq_str)
    end
  end

  def filter_individual_issues(solr_parameters)
    return unless solr_parameters

    val = blacklight_params[:include_issues] || blacklight_params['include_issues']
    if val.nil? && scope.respond_to?(:params)
      val = scope.params[:include_issues] || scope.params['include_issues']
    end

    # By default (checked), include issues. Filter out individual issues when unchecked (include_issues=0).
    if val == '0' || val == 'false' || val == false
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] = Array(solr_parameters[:fq])
      solr_parameters[:fq] << '-is_issue:Yes' unless solr_parameters[:fq].include?('-is_issue:Yes')
    end
  end

  def tag_and_exclude_facets(solr_parameters)
    return unless solr_parameters

    # Map each facet field key and Solr field to a unique tag name
    facet_configs = blacklight_config.facet_fields
    tag_map = {}
    facet_configs.each do |key, config|
      solr_field = (config&.field || key).to_s
      tag = "tag_#{key.to_s.parameterize.underscore}"
      tag_map[key.to_s] = tag
      tag_map[solr_field] = tag
    end

    # 1. Normalize and Tag all filter queries in :fq (remove string 'fq' to prevent duplicate params)
    combined_fqs = Array(solr_parameters.delete('fq')) + Array(solr_parameters[:fq])
    if combined_fqs.present?
      solr_parameters[:fq] = combined_fqs.map do |fq_entry|
        next fq_entry unless fq_entry.is_a?(String)

        # Match which facet field this filter belongs to
        matched_tag = nil
        tag_map.each do |field_name, tag|
          if fq_entry =~ /(?:f=#{Regexp.escape(field_name)}\b|\b#{Regexp.escape(field_name)}\s*:)/
            matched_tag = tag
            break
          end
        end

        if matched_tag && !fq_entry.include?("tag=#{matched_tag}")
          if fq_entry.start_with?('{!')
            fq_entry.sub(/\A\{!/, "{!tag=#{matched_tag} ")
          else
            "{!tag=#{matched_tag}}#{fq_entry}"
          end
        else
          fq_entry
        end
      end.uniq
    end

    # 2. Normalize and Exclude corresponding tags in :'facet.field' (remove string keys to prevent duplicate Solr params)
    raw_facet_fields = Array(solr_parameters.delete('facet.field')) +
                       Array(solr_parameters.delete(:facet_field)) +
                       Array(solr_parameters.delete('facet_field')) +
                       Array(solr_parameters[:'facet.field'])

    if raw_facet_fields.present?
      solr_parameters[:'facet.field'] = raw_facet_fields.map do |field_entry|
        next field_entry unless field_entry.is_a?(String)

        clean_field = field_entry.sub(/\A\{![^}]*\}\s*/, '')
        tag = tag_map[clean_field]

        if tag && !field_entry.include?("ex=#{tag}")
          "{!ex=#{tag} key=#{clean_field}}#{clean_field}"
        else
          field_entry
        end
      end.uniq
    end
  end
end
