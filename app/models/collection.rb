class FakeSuperCollection
  def name
    "Algemeen"
  end

  def themes
    Theme.general
  end

  def not_hidden_themes
    themes.not_hidden
  end
end

class Collection < ApplicationRecord
  has_many :works
  has_many :clusters
  has_many :import_collections
  has_many :themes
  has_many :artists, through: :works
  has_many :batch_photo_uploads
  belongs_to :parent_collection, class_name: 'Collection'
  has_many :child_collections, class_name: 'Collection', foreign_key: 'parent_collection_id'
  has_and_belongs_to_many :users
  default_scope ->{order(:name)}
  scope :without_parent, ->{where(parent_collection_id: nil)}

  def works_including_child_works
    Work.where(collection_id: id_plus_child_ids)
  end

  def clusters_including_parent_clusters
    Cluster.where(collection_id: id_plus_parent_ids)
  end

  def not_hidden_themes
    themes.not_hidden
  end

  def users_including_parent_users
    (users + parent_collections_flattened.collect{|a| a.users_including_parent_users}).flatten.uniq
  end

  def id_plus_child_ids
    child_collections_flattened.collect{|a| a.id} + [self.id]
  end

  def id_plus_parent_ids
     (self.parent_collections_flattened.map(&:id) + [self.id]).flatten.uniq.compact
  end

  def exposable_fields= array
    write_attribute(:exposable_fields,array.collect{|a| a.to_s.strip if a and a.to_s.strip != ""}.compact.join(","))
  end

  def possible_parent_collections
    Collection.all - [self] - child_collections_flattened
  end

  def child_collections_flattened
    a = child_collections
    a += child_collections.collect{|a| a.child_collections_flattened}
    a.flatten
  end

  def parent_collections_flattened
    ([parent_collection] + [parent_collection].compact.collect{|a| a.parent_collection}.flatten).compact.reverse
  end

  def self_and_parent_collections_flattened
    Collection.where(id: id_plus_parent_ids)
  end

  def collection_name_extended
    # inefficient... but needed for proper order
    ids = parent_collections_flattened + [self.id]
    names = []
    ids.each do | collection_id |
      c = Collection.where(id:collection_id).select(:name).first
      names << c.name if c
    end
    names.join(" » ")
  end

  def available_themes
    (self_and_parent_collections_flattened.collect{|a| a.themes.not_hidden} + Theme.all.not_hidden.general).flatten.uniq.compact
  end

  def exposable_fields
    read_attribute(:exposable_fields).to_s.split(",")
  end

  def fields_to_expose(audience=:default)
    if audience == :default
      return exposable_fields.count == 0 ? Collection.possible_exposable_fields.collect{|k,v| v} : exposable_fields
    elsif audience == :hpd
      return ["stock_number","title_rendered","description","artist_name_rendered","hpd_height","hpd_width","hpd_depth","hpd_diameter","hpd_keywords","hpd_materials","hpd_condition","hpd_photo_file_name","hpd_comments","hpd_contact"]
    end
  end

  def expose?(field_name)
    return true if exposable_fields.count == 0
    return true if !Collection.possible_exposable_fields.collect{|a| a[1]}.include? field_name.to_s
    exposable_fields.include? field_name.to_s
  end

  def elastic_aggragations
    elastic_report = search_works("",{},{force_elastic: true, return_records: false})
    return elastic_report.aggregations
  end

  def label_override_work_alt_number_1_with_inheritance
    self_and_parent_collections_flattened.collect{|a| a.label_override_work_alt_number_1 unless a.label_override_work_alt_number_1.to_s.strip == ""}.compact.last
  end

  def label_override_work_alt_number_2_with_inheritance
    self_and_parent_collections_flattened.collect{|a| a.label_override_work_alt_number_2 unless a.label_override_work_alt_number_2.to_s.strip == ""}.compact.last
  end

  def label_override_work_alt_number_3_with_inheritance
    self_and_parent_collections_flattened.collect{|a| a.label_override_work_alt_number_3 unless a.label_override_work_alt_number_3.to_s.strip == ""}.compact.last
  end

  def report
    return @report if @report
    @report = {}

    elastic_aggragations.each do |key, set|
      counts = parse_aggregation(set, key)
      key = key.gsub(/_missing$/,"")
      @report[key.to_sym] = {} unless @report[key.to_sym]
      @report[key.to_sym].deep_merge!(counts) if counts
    end


    return @report
  end

  def parse_aggregation aggregation, aggregation_key
    counts = {}
    # raise aggregation
    if aggregation.is_a? Hash and aggregation[:doc_count] and aggregation_key.to_s.match(/^.*\_missing$/)
      counts[:missing] = {count: aggregation[:doc_count], subs: {}}
    elsif aggregation.is_a? Hash and aggregation[:buckets]
      buckets = aggregation.buckets #.sort{|a,b| a[:key]<=>b[:key]}
      # raise buckets
      buckets.each do |bucket|
        subcounts_in_hash = {}
        bucket.each do |subkey, subset|
          sub_counts = parse_aggregation(subset,subkey)
          subkey = subkey.gsub(/_missing$/,"")

          subcounts_in_hash[subkey.to_sym] = sub_counts if sub_counts
        end
        key = parse_bucket_key(aggregation_key,bucket["key"])
        key_model_relations={
          "artists"=>Artist,
          "themes"=>Theme,
          "object_categories"=>ObjectCategory,
          "object_categories_split"=>ObjectCategory,
          "techniques"=>Technique,
          "condition_frame"=>Condition,
          "techniques_split"=>Technique,
          "condition_work"=>Condition,
          "frame_damage_types"=>FrameDamageType,
          "damage_types"=>DamageType,
          "placeability"=>Placeability,
          "style"=>Style,
          "subset"=>Subset,
          "source"=>Source,
          "cluster"=>Cluster,
        }
        key_model = key_model_relations[aggregation_key]
        if key_model
          key = key_model.send(:names, key)
        end
        counts[key] = {count: bucket.doc_count, subs: subcounts_in_hash }
      end
    end
    return counts unless ["key","doc_count", "total"].include?(aggregation_key)
  end

  def parse_bucket_key aggregation_key, bucket_key
    bucket_key_parsed = bucket_key

    unless ["abstract_or_figurative", "object_format_code", "grade_within_collection", "location", "location_raw"].include?(aggregation_key)
      bucket_key_parsed = bucket_key.to_s.split(",").map(&:to_i)
    end
    return bucket_key_parsed
  end

  # search (to be implemented)
  # filter
  def search_works(search="", filter={}, options={})
    options = {force_elastic: false, return_records: true}.merge(options)
    if ((search == "" or search == nil) and (filter == nil or filter == {} or (
      filter.is_a? Hash and filter.sum{|k,v| v.count} == 0
      )) and options[:force_elastic] == false)
      return options[:no_child_works] ? works : works_including_child_works
    end

    query = {
      size: 10000,
      query:{
        filtered:{
          filter:{
            bool: {
              must: [
                terms:{
                  "collection_id"=> options[:no_child_works] ? [id] : id_plus_child_ids
                }
              ]
            }
          }
        }
      }
    }

    if (search and search.to_s.strip != "")
      query[:query][:filtered][:query] = {
        fuzzy: {
          _all: search
        }
      }
    end

    filter.each do |key, values|
      new_bool = {bool: {should: []}}
      values.each do |value|
        if value != nil
          new_bool[:bool][:should] << {term: {key=>value}}
        else
          if key.ends_with?(".id")
            new_bool[:bool][:should] << {not: {exists: {field: key}}}
          else
            new_bool[:bool][:should] << {missing: {field: key }}
          end
        end
      end
      query[:query][:filtered][:filter][:bool][:must] << new_bool
    end

    query[:aggs] = {
      total: {
        value_count: {
          field: :id
        }
      },
      market_value: {
          histogram: {
              field: :market_value,
              interval: 1,
          }
      },
      market_value_missing: {
        missing: {
          field: :market_value
        }
      },
      replacement_value:  {
          histogram: {
              field: :replacement_value,
              interval: 1,
          }
      },
      replacement_value_missing: {
        missing: {
          field: :replacement_value
        }
      },
      artists: {
        terms: {
          field: :report_val_sorted_artist_ids, size: 0
        }
      },
      artists_missing: {
        missing: {
          field: :report_val_sorted_artist_ids
        }
      },
      object_categories: {
        terms: {
          field: :report_val_sorted_object_category_ids, size: 0
        },
        aggs: {
          techniques: {
            terms: {
              field: :report_val_sorted_technique_ids, size: 0
            }
          },
          techniques_missing: {
            missing: {
              field: :report_val_sorted_technique_ids
            }
          }
        }
      },
      object_categories_missing: {
        missing: {
          field: :report_val_sorted_object_category_ids
        },
        aggs: {
          techniques: {
            terms: {
              field: :report_val_sorted_technique_ids, size: 0
            }
          },
          techniques_missing: {
            missing: {
              field: :report_val_sorted_technique_ids
            }
          }
        }
      },
      object_categories_split: {
        terms: {
          field: :report_val_sorted_object_category_ids, size: 0
        },
        aggs: {
          techniques: {
            terms: {
              field: "techniques.id", size: 0
            }
          },
          techniques_missing: {
            missing: {
              field: "techniques.id"
            }
          }
        }
      },
      object_categories_split_missing: {
        missing: {
          field: :report_val_sorted_object_category_ids
        },
        aggs: {
          techniques: {
            terms: {
              field: "techniques.id", size: 0
            }
          },
          techniques_missing: {
            missing: {
              field: "techniques.id"
            }
          }
        }
      }
    }

    [:subset, :cluster, :style].each do |key|
      query[:aggs].merge!(basic_aggregation_snippet(key,"_id"))
    end

    [:condition_work, :condition_frame, :sources, :placeability, :themes ].each do |key|
      query[:aggs].merge!(basic_aggregation_snippet_with_missing(key,".id"))
    end

    [:damage_types, :frame_damage_types].each do |key|
      query[:aggs].merge!(basic_aggregation_snippet(key,".id"))
    end

    [:abstract_or_figurative, :grade_within_collection, :location_raw, :object_format_code, :object_creation_year].each do |key|
      query[:aggs].merge!(basic_aggregation_snippet_with_missing(key))
    end

    if options[:return_records]
      return Work.search(query).records
    else
      return Work.search(query)
    end
  end

  def basic_aggregation_snippet key, postfix = "", field = nil
    {
      key => {
        terms: {
          field:  "#{key}#{postfix}", size: 0
        }
      }
    }
  end

  def basic_aggregation_snippet_with_missing key, postfix = "", field = nil
    rv = basic_aggregation_snippet(key, postfix, field)
    rv["#{key}_missing".to_sym] = {
      missing: {
        field: "#{key}#{postfix}"
      }
    }
    rv
  end


  def can_be_accessed_by_user user
    users_including_parent_users.include? user or user.admin?
  end

  class << Collection
    def all_plus_a_fake_super_collection
      [FakeSuperCollection.new] + self.all
    end
    def for_user user
      return self if user.admin?
      return self.joins(:users).where(users: {id: user.id})
    end
    def possible_exposable_fields
      return @@possible_exposable_fields if defined? @@possible_exposable_fields
      set = []
      fields = Work.new.methods.collect do |method|
        if method.to_s.match(/=/) and !method.to_s.match(/^(before|after|\_|\=|\<|\!|\[|photo_|remote\_|remove\_|defined\_enums|find\_by\_statement\_cache|validation\_context|record\_timestamps|aggregate\_reflections|include\_root\_in\_json|destroyed\_by\_association|attributes|entry_status_description|entry_status|paper_trail|verions)(.*)/) and !method.to_s.match(/(.*)\_(id|ids|attributes|class_name|association_name|cache)\=$/)
          method.to_s.gsub(/\=/,'')
        end
      end.compact

      #sort_according_to_form
      #
      formstring = File.open('app/views/works/_form.html.erb').read
      fields.sort! do |a,b|
        a1 = formstring.index(":#{a}") ? formstring.index(":#{a}") : 9999999
        b1 = formstring.index(":#{b}") ? formstring.index(":#{b}") : 9999999
        a1 <=> b1
      end

      return @@possible_exposable_fields = fields.collect{|a| [Work.human_attribute_name(a.to_s),a] }
    end
  end
end
