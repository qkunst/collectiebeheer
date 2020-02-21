# frozen_string_literal: true

require_relative "../uploaders/picture_uploader"
class Work < ApplicationRecord
  SORTING_FIELDS = [:inventoried_at, :stock_number, :created_at]
  GRADES_WITHIN_COLLECTION = %w{A B C D E F G W}

  include ActionView::Helpers::NumberHelper
  include Work::Caching
  include Work::Export
  include Work::ParameterRerendering
  include Work::PreloadRelationsForDisplay
  include FastAggregatable
  include Searchable
  include MethodCache

  has_paper_trail

  has_cache_for_method :tag_list
  has_cache_for_method :collection_locality_artist_involvements_texts

  before_save :set_empty_values_to_nil
  before_save :sync_purchase_year
  before_save :enforce_nil_or_true
  before_save :update_created_by_name
  before_save :convert_purchase_price_in_eur
  after_save  :touch_collection!
  after_save  :update_artist_name_rendered!
  before_save :cache_tag_list!
  before_save :cache_collection_locality_artist_involvements_texts!

  belongs_to :cluster, optional: true
  belongs_to :collection
  belongs_to :owner, optional: true
  belongs_to :condition_frame, class_name: "Condition", optional: true
  belongs_to :condition_work, class_name: "Condition", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :frame_type, optional: true
  belongs_to :medium, optional: true
  belongs_to :placeability, optional: true
  belongs_to :purchase_price_currency, class_name: "Currency", optional: true
  belongs_to :style, optional: true
  belongs_to :subset, optional: true
  has_and_belongs_to_many :artists, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :damage_types, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :frame_damage_types, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :object_categories, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :sources, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :techniques, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :themes, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :custom_reports
  has_many :appraisals
  has_many :attachments, as: :attache
  has_many :messages, as: :subject_object

  scope :artist, ->(artist){ joins("INNER JOIN artists_works ON works.id = artists_works.work_id").where(artists_works: {artist_id: artist.id})}
  scope :has_number, ->(number){ number.blank? ? none : where(stock_number: number).or(where(alt_number_1: number)).or(where(alt_number_2: number)).or(where(alt_number_3: number)) }
  scope :id, ->(ids) { where(id: ids) }
  scope :no_photo_front, -> { where(photo_front: nil)}
  scope :order_by, ->(sort_key) do
    case sort_key.to_sym
    when :location
      order(:location, Arel.sql("works.location_floor = '-3' DESC, works.location_floor = '-2' DESC, works.location_floor = '-1' DESC, works.location_floor = '0' DESC, works.location_floor = 'BG' DESC"), :location_floor, :location_detail)
    when :created_at
      order(created_at: :desc)
    when :artist_name, :artist_name_rendered
      left_outer_joins(:artists).order(Arel.sql("artists.id IS NULL ASC, artists.last_name ASC, artists.first_name ASC"))
    when :stock_number
      order(:stock_number)
    end
  end
  scope :published, ->{ where(publish: true) }

  accepts_nested_attributes_for :artists
  accepts_nested_attributes_for :appraisals

  validates_with Validators::CollectionScopeValidator

  acts_as_taggable

  normalize_attributes :location, :stock_number, :alt_number_1, :alt_number_2, :alt_number_3, :photo_front, :photo_back, :photo_detail_1, :photo_detail_2, :title, :print, :grade_within_collection, :entry_status, :abstract_or_figurative, :location_detail

  mount_uploader :photo_front, PictureUploader
  mount_uploader :photo_back, PictureUploader
  mount_uploader :photo_detail_1, PictureUploader
  mount_uploader :photo_detail_2, PictureUploader

  time_as_boolean :inventoried
  time_as_boolean :refound
  time_as_boolean :new_found

  attr_localized :frame_height, :frame_width, :frame_depth, :frame_diameter, :height, :width, :depth, :diameter

  accepts_nested_attributes_for :appraisals

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

  def photos?
    photo_front? or photo_back? or photo_detail_1? or photo_detail_2?
  end

  # This method is built to be fault tolerant and tries to make the best out of user given input.
  def purchased_on= date
    if date.is_a? String
      begin
        date = date.to_date
      rescue ArgumentError
      end
    end
    if date.is_a? String or date.is_a? Numeric
      date = date.to_i
      if date > 1900 and date < 2100
        self.write_attribute(:purchase_year, date)
      end
    else
      if date.is_a? Date or date.is_a? Time or date.is_a? DateTime
        self.write_attribute(:purchased_on, date)
        self.write_attribute(:purchase_year, date.year)
      end
    end
  end

  def cluster_name= name
    stripped_name = name.to_s.strip
    if stripped_name == ""
      self.cluster = nil
    else
      clust = self.collection.available_clusters.find_by_case_insensitive_name(stripped_name).first
      self.cluster = clust
      if self.cluster.nil?
        self.cluster = self.collection.base_collection.clusters.create!(name: stripped_name)
      end
    end
  end


  def sync_purchase_year
    if purchased_on
      self.purchase_year = purchased_on.year
    end
  end

  def can_be_accessed_by_user?(user)
    user.admin? || collection.can_be_accessed_by_user?(user)
  end

  def geoname_ids
    ids = artists.flat_map(&:cached_geoname_ids)
    ids << locality_geoname_id if locality_geoname_id
    GeonameSummary.where(geoname_id: ids).with_parents.select(:geoname_id).collect{|a| a.geoname_id}
  end

  def alt_numbers
    nrs = [alt_number_1, alt_number_2, alt_number_3]
    nrs if nrs.count > 0
  end

  def purchase_price_symbol
    purchase_price_currency ? purchase_price_currency.symbol : "€"
  end

  def dimension_to_s value, nil_value=nil
    value ? number_with_precision(value, precision: 5, significant: true, strip_insignificant_zeros: true) : nil_value
  end

  def main_collection
    read_attribute(:main_collection) ? true : nil
  end

  def collection_external_reference_code
    collection.external_reference_code if collection
  end

  def all_work_ids_in_collection
    return @all_work_ids_in_collection if @all_work_ids_in_collection
    order = [collection.sort_works_by, collection.parent_collection.try(:sort_works_by), :stock_number, :id]

    relative_collection = (!order[0] && order[1]) ? collection.parent_collection : collection

    @all_work_ids_in_collection ||= relative_collection.works_including_child_works.select(:id).order(order.compact).collect{|a| a.id}
  end

  def work_index_in_collection
    @work_index_in_collection ||= all_work_ids_in_collection.index(self.id)
  end

  def next
    next_work_id = all_work_ids_in_collection[work_index_in_collection+1]
    next_work_id ? Work.find(next_work_id) : Work.find(all_work_ids_in_collection.first)
  end

  def previous
    prev_work_id = all_work_ids_in_collection[work_index_in_collection-1]
    prev_work_id ? Work.find(prev_work_id) : Work.find(all_work_ids_in_collection.last)
  end

  def set_empty_values_to_nil
    #especially important for elasticsearch filtering on empty values!
    if grade_within_collection.is_a? String and grade_within_collection.strip == ""
      self.grade_within_collection=nil
    end

    if public_description == ""
      self.public_description = nil
    end
  end

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

  def report_val_sorted_artist_ids
    artists.order_by_name.distinct.collect{|a| a.id}.sort.join(",")
  end
  def report_val_sorted_object_category_ids
    object_categories.uniq.collect{|a| a.id}.sort.join(",")
  end
  def report_val_sorted_technique_ids
    techniques.uniq.collect{|a| a.id}.sort.join(",")
  end
  def report_val_sorted_theme_ids
    themes.uniq.collect{|a| a.id}.sort.join(",")
  end
  def available_themes
    collection.available_themes
  end

  def add_lognoteline note
    self.lognotes = self.lognotes.to_s + "\n#{note}"
  end

  def title= titel
    if titel.to_s.strip == ""
      write_attribute(:title, nil)
    elsif ["zonder titel", "onbekend"].include? titel.to_s.strip.downcase
      write_attribute(:title_unknown, true)
    else
      write_attribute(:title, titel)
    end
  end

  def object_creation_year= year
    if year.to_i > 0
      write_attribute(:object_creation_year, year)
    elsif ["geen jaar", "zonder jaartal", "onbekend"].include? year.to_s
      write_attribute(:object_creation_year_unknown, true)
    end
  end

  def object_creation_year
    object_creation_year_unknown ? nil : read_attribute(:object_creation_year)
  end

  def signature_comments= sig
    if sig.to_s.strip == ""
      write_attribute(:signature_comments, nil)
    elsif sig.to_s.strip.downcase == "niet gesigneerd"
      write_attribute(:no_signature_present, true)
    else
      write_attribute(:signature_comments, sig)
    end
  end

  def enforce_nil_or_true
    self.main_collection = nil if self.main_collection == false
  end

  def touch_updated_at(*)
    self.touch if persisted?
  end

  def touch_collection!
    collection.touch if collection
  end

  def convert_purchase_price_in_eur
    self.purchase_price_in_eur = purchase_price_currency.to_eur(purchase_price) if purchase_price and purchase_price_currency
  end

  class << self
    def collect_locations
      rv = {}
      self.group(:location).count.sort{|a,b| a[0].to_s.downcase<=>b[0].to_s.downcase }.each{|a| rv[a[0]] = {count: a[1], subs:[]} }
      rv
    end
    def human_attribute_name_for_alt_number_field( field_name, collection )
      custom_label_name = collection ? collection.send("label_override_work_#{field_name}_with_inheritance".to_sym) : nil
      custom_label_name || Work.human_attribute_name(field_name)
    end
    def human_attribute_name_overridden( field_name, collection )
      if [:alt_number_1, :alt_number_2, :alt_number_3].include? field_name
        human_attribute_name_for_alt_number_field( field_name, collection )
      else
        Work.human_attribute_name(field_name)
      end
    end
    def column_types
      return @@column_types if defined?(@@column_types)
      @@column_types = Work.columns.collect{|a| [a.name, a.type]}.to_h
      @@column_types["inventoried"] = :boolean
      @@column_types["refound"] = :boolean
      @@column_types["new_found"] = :boolean
      @@column_types
    end
  end
end
