# frozen_string_literal: true

module Work::Search
  extend ActiveSupport::Concern

  included do

    settings index: { number_of_shards: 5, max_result_window: 50_000 } do
      mappings do
        indexes :abstract_or_figurative, type: 'keyword'
        indexes :tag_list, type: 'keyword'#, tokenizer: 'keyword'
        indexes :description, analyzer: 'dutch', index_options: 'offsets'
        indexes :grade_within_collection, type: 'keyword'
        indexes :location_raw, type: 'keyword'
        indexes :location_floor_raw, type: 'keyword'
        indexes :location_detail_raw, type: 'keyword'
        indexes :object_format_code, type: 'keyword'
        indexes :report_val_sorted_artist_ids, type: 'keyword'
        indexes :report_val_sorted_object_category_ids, type: 'keyword'
        indexes :report_val_sorted_technique_ids, type: 'keyword'
        indexes :title, analyzer: 'dutch'
        indexes :market_value, type: 'scaled_float', scaling_factor: 100
        indexes :replacement_value, type: 'scaled_float', scaling_factor: 100
        indexes :market_value, type: 'scaled_float', scaling_factor: 100
        indexes :purchase_price, type: 'scaled_float', scaling_factor: 100
        indexes :market_value_min, type: 'scaled_float', scaling_factor: 100
        indexes :market_value_max, type: 'scaled_float', scaling_factor: 100
        indexes :replacement_value_min, type: 'scaled_float', scaling_factor: 100
        indexes :replacement_value_max, type: 'scaled_float', scaling_factor: 100
        indexes :minimum_bid, type: 'scaled_float', scaling_factor: 100
        indexes :selling_price, type: 'scaled_float', scaling_factor: 100
        indexes :purchase_price_in_eur, type: 'scaled_float', scaling_factor: 100
      end
    end

    index_name "works-#{Rails.env.test? ? "test" : "a"}"

    def as_indexed_json(*)
      self.as_json(
        include: {
          sources: { only: [:id, :name]},
          style: { only: [:id, :name]},
          owner: { only: [:id, :name]},
          artists: { only: [:id, :name], methods: [:name]},
          object_categories: { only: [:id, :name]},
          medium: { only: [:id, :name]},
          condition_work: { only: [:id, :name]},
          damage_types: { only: [:id, :name]},
          condition_frame: { only: [:id, :name]},
          frame_damage_types: { only: [:id, :name]},
          techniques: { only: [:id, :name]},
          themes: { only: [:id, :name]},
          subset: { only: [:id, :name]},
          placeability: { only: [:id, :name]},
          cluster: { only: [:id, :name]},
        },
        methods: [
          :tag_list, :geoname_ids, :title_rendered, :artist_name_rendered,
          :report_val_sorted_artist_ids, :report_val_sorted_object_category_ids, :report_val_sorted_technique_ids, :report_val_sorted_theme_ids,
          :location_raw, :location_floor_raw, :location_detail_raw,
          :object_format_code, :inventoried, :refound, :new_found
        ]
      )
    end

  end

  class_methods do
    def search_and_filter(base_collection, search="", filter={}, options={})
      options = {force_elastic: false, return_records: true, limit: 50000}.merge(options)
      sort = options[:sort] || ["_score"]

      if !use_elasticsearch?(search, filter, options[:force_elastic])
        return options[:no_child_works] ? base_collection.works.limit(options[:limit]) : base_collection.works_including_child_works.limit(options[:limit])
      end

      query = {
        _source: [:id], #major speedup!
        size: options[:limit],
        query:{
          bool: {
            must: [
              terms:{
                "collection_id"=> options[:no_child_works] ? [base_collection.id] : base_collection.expand_with_child_collections.map(&:id)
              }
            ]
          }
        },
        sort: sort
      }


      query[:query][:bool][:must] += search_to_elasticsearch_filter(search)
      query[:query][:bool][:must] += filter_to_elasticsearch_filter(filter)

      query[:aggs] = options[:aggregations] if options[:aggregations]

      if options[:return_records]
        Work.search(query).records
      else
        Work.search(query)
      end
    end

    private

    def use_elasticsearch?(search, filter, force_elasticsearch)
      !((search == "" || search == nil) &&
      (filter == nil || filter == {} || (filter.is_a?(Hash) && filter.sum{|k,v| v.count} == 0)) &&
      !force_elasticsearch)
    end

    def filter_to_elasticsearch_filter(filter_hash)
      filter_hash.collect do |key, values|
        new_bool = {bool: {should: []}}
        if key == "locality_geoname_id" or key == "geoname_ids" or key == "tag_list"
          values = values.compact
          if values.count == 0
            new_bool[:bool]= {mustNot: {exists: {field: key}}}
          else
            new_bool[:bool][:should] << {terms: {key=> values}}
          end
        else
          values.each do |value|
            if value != nil
              new_bool[:bool][:should] << {term: {key=>value}}
            else
              if key.ends_with?(".id")
                new_bool[:bool][:should] << {mustNot: {exists: {field: key}}}
              else
                new_bool[:bool][:should] << {bool:{must_not: {exists: {field: key }}}}
              end
            end
          end
        end
        new_bool
      end
    end

    def search_to_elasticsearch_filter(search)
      if (search and !search.to_s.strip.empty?)
        search = search.match(/[\"\(\~\'\*\?]|AND|OR/) ? search : search.split(" ").collect{|a| "#{a}~" }.join(" ")
        [{
          query_string: {
            default_field: :_all,
            query: search,
            default_operator: :and,
            fuzziness: 3
          }
        }]
      else
        []
      end
    end
  end
end