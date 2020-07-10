# frozen_string_literal: true

module Report
  class Builder
    extend Report::BuilderHelpers

    class << self
      def aggregations
        aggregation = {
          total: {
            value_count: {
              field: :id
            }
          },
          artists: {
            terms: {
              field: "report_val_sorted_artist_ids", size: 10_000
            }
          },
          object_categories: {
            terms: {
              field: "report_val_sorted_object_category_ids", size: 999
            },
            aggs: {
              techniques: {
                terms: {
                  field: "report_val_sorted_technique_ids", size: 999
                }
              },
              techniques_missing: {
                missing: {
                  field: "report_val_sorted_technique_ids"
                }
              }
            }
          },

          object_categories_split: {
            terms: {
              field: "report_val_sorted_object_category_ids", size: 999
            },
            aggs: {
              techniques: {
                terms: {
                  field: "techniques.id", size: 999
                }
              },
              techniques_missing: {
                missing: {
                  field: "techniques.id"
                }
              }
            }
          }
          #
          # :market_value_range=>{
          #   :terms=>{
          #     :field=>:market_value_min, :size=>999
          #   }
          # },
          # "market_value_range_missing"=>{:missing=>{:field=>:market_value_min}},
          # :aggs=>{:market_value_max_range=>{:terms=>{:field=>:market_value_max, :size=>999}}, "market_value_max_range_missing"=>{:missing=>{:field=>:market_value_max}}}}
          #
        }

        [:subset, :style, :frame_type].each do |key|
          aggregation.merge!(basic_aggregation_snippet(key, "_id"))
        end

        [:condition_work, :condition_frame, :sources, :placeability, :themes, :owner, :cluster, :work_status].each do |key|
          aggregation.merge!(basic_aggregation_snippet_with_missing(key, ".id"))
        end

        [:damage_types, :frame_damage_types].each do |key|
          aggregation.merge!(basic_aggregation_snippet(key, ".id"))
        end

        ["abstract_or_figurative", "grade_within_collection", "object_format_code", "tag_list", :market_value, :market_value_min, :market_value_max, :replacement_value, :replacement_value_min, :replacement_value_max, :object_creation_year, :purchase_year, :purchase_price_in_eur, :minimum_bid, :selling_price, :publish, :image_rights].each do |key|
          aggregation.merge!(basic_aggregation_snippet_with_missing(key))
        end

        [:inventoried, :refound, :new_found].each do |key|
          aggregation.merge!(basic_aggregation_snippet(key))
        end

        market_value_range = basic_aggregation_snippet_with_missing(:market_value_range, "", :market_value_min)
        market_value_range[:market_value_range][:aggs] = basic_aggregation_snippet(:market_value_max)
        aggregation.merge!(market_value_range)

        replacement_value_range = basic_aggregation_snippet_with_missing(:replacement_value_range, "", :replacement_value_min)
        replacement_value_range[:replacement_value_range][:aggs] = basic_aggregation_snippet(:replacement_value_max)
        aggregation.merge!(replacement_value_range)

        location_sub_sub = basic_aggregation_snippet_with_missing("location_detail_raw")

        location_sub = basic_aggregation_snippet_with_missing("location_floor_raw")
        location_sub.keys.each do |key|
          location_sub[key][:aggs] = location_sub_sub
        end

        location = basic_aggregation_snippet_with_missing("location_raw")
        location.keys.each do |key|
          location[key][:aggs] = location_sub
        end

        aggregation.merge!(location)

        aggregation
      end
    end
  end
end
