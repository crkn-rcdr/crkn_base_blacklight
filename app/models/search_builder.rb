# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightRangeLimit::RangeLimitBuilder


  self.default_processor_chain += [
    :add_inclusive_facet_fq_to_solr,
    :tag_and_exclude_facets,
    :filter_individual_issues,
    :boost_and_expand_id_queries
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
      next if config&.query

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
      if config&.query.is_a?(Hash)
        config.query.each do |_qkey, qconf|
          tag_map[qconf[:fq]] = tag if qconf[:fq]
        end
      end
    end

    # 1. Normalize and Tag all filter queries in :fq (remove string 'fq' to prevent duplicate params)
    combined_fqs = Array(solr_parameters.delete('fq')) + Array(solr_parameters[:fq])
    if combined_fqs.present?
      solr_parameters[:fq] = combined_fqs.map do |fq_entry|
        next fq_entry unless fq_entry.is_a?(String)

        # Match which facet field this filter belongs to
        matched_tag = nil
        tag_map.each do |field_name, tag|
          if fq_entry == field_name || fq_entry =~ /(?:f=#{Regexp.escape(field_name)}\b|\b#{Regexp.escape(field_name)}\s*:)/
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

    # 3. Normalize and Exclude corresponding tags in :'facet.query'
    raw_facet_queries = Array(solr_parameters.delete('facet.query')) +
                        Array(solr_parameters.delete(:facet_query)) +
                        Array(solr_parameters.delete('facet_query')) +
                        Array(solr_parameters[:'facet.query'])

    if raw_facet_queries.present?
      solr_parameters[:'facet.query'] = raw_facet_queries.map do |query_entry|
        next query_entry unless query_entry.is_a?(String)

        # Ensure local params have key='...' matching query for proper Blacklight facet parsing
        if query_entry =~ /\A\{!ex=([^}]+)\}(.+)\z/
          tag_name = $1
          orig_query = $2
          "{!ex=#{tag_name} key='#{orig_query}'}#{orig_query}"
        else
          query_entry
        end
      end.uniq
    end
  end

  def boost_and_expand_id_queries(solr_parameters)
    return unless solr_parameters

    search_field = (blacklight_params[:search_field] || blacklight_params['search_field'])&.to_s
    return if search_field.present? && search_field != 'all_fields'

    raw_q = (blacklight_params[:q] || blacklight_params['q'])&.to_s&.strip
    return if raw_q.blank?

    solr_parameters[:bq] ||= []
    solr_parameters[:bq] = Array(solr_parameters[:bq])

    # Single-token query without special Solr query syntax
    if raw_q =~ /\A[a-zA-Z0-9_\-\.]+\z/
      candidates = generate_id_candidates(raw_q)
      candidates.each do |cid|
        escaped_id = cid.gsub('"', '\\"')
        clause = "id:\"#{escaped_id}\"^50000"
        solr_parameters[:bq] << clause unless solr_parameters[:bq].include?(clause)
      end

      # Unless the user already prefixed with oocihm., expand solr_parameters[:q] so
      # bare identifiers (e.g. N_00005, 72118, 117878, h2971) match the record's ID
      unless raw_q.downcase.start_with?('oocihm.')
        id_clauses = candidates.map { |cid| "id:\"#{cid.gsub('"', '\\"')}\"" }.uniq
        solr_parameters[:q] = "(#{raw_q}) OR #{id_clauses.join(' OR ')}"
        solr_parameters[:mm] = 1
      end
    else
      # Multi-word query (e.g. "MIKAN 117878", "reel H2971", "CIHM 72118")
      tokens = raw_q.scan(/[a-zA-Z0-9_\-\.]+/)
      tokens.each do |tok|
        next if tok.length < 3 || tok.length > 50
        next if tok =~ /\A(?:the|and|for|from|with|dans|avec|pour)\z/i

        candidates = generate_id_candidates(tok)
        candidates.each do |cid|
          escaped_id = cid.gsub('"', '\\"')
          clause = "id:\"#{escaped_id}\"^50000"
          solr_parameters[:bq] << clause unless solr_parameters[:bq].include?(clause)
        end
      end
    end
  end

  def generate_id_candidates(term)
    candidates = [
      term,
      term.downcase,
      term.upcase
    ]

    if term.downcase.start_with?('oocihm.')
      base = term.sub(/\Aoocihm\./i, '')
      candidates << base
      candidates << base.downcase
      candidates << base.upcase
      if base =~ /\Alac_mikan_(.+)\z/i
        candidates << $1
      elsif base =~ /\Alac_reel_(.+)\z/i
        candidates << $1
        candidates << $1.downcase
      end
    else
      candidates << "oocihm.#{term}"
      candidates << "oocihm.#{term.downcase}"
      candidates << "oocihm.#{term.upcase}"
      candidates << "oocihm.lac_mikan_#{term}"
      candidates << "oocihm.lac_reel_#{term}"
      candidates << "oocihm.lac_reel_#{term.downcase}"
      candidates << "oocihm.lac_reel_#{term.upcase}"

      if term =~ /\A(?:lac_)?reel_(.+)\z/i
        reel_num = $1
        candidates << "oocihm.lac_reel_#{reel_num}"
        candidates << "oocihm.lac_reel_#{reel_num.downcase}"
      elsif term =~ /\A(?:lac_)?mikan_(.+)\z/i
        mikan_num = $1
        candidates << "oocihm.lac_mikan_#{mikan_num}"
      end
    end

    candidates.uniq
  end
end
