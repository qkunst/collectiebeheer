require_relative "../uploaders/picture_uploader"
class Work < ApplicationRecord
  has_paper_trail
  before_save :set_empty_values_to_nil
  before_save :sync_purchase_year
  before_save :enforce_nil_or_true
  after_save :update_artist_name_rendered!

  include ActionView::Helpers::NumberHelper
  include Searchable

  belongs_to :cluster
  belongs_to :collection
  belongs_to :condition_frame, :class_name=>Condition
  belongs_to :condition_work, :class_name=>Condition
  belongs_to :created_by, :class_name=>User
  belongs_to :frame_type
  belongs_to :medium
  belongs_to :placeability
  belongs_to :purchase_price_currency, :class_name=>Currency
  belongs_to :style
  belongs_to :subset
  has_and_belongs_to_many :artists, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :damage_types, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :frame_damage_types, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :object_categories, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :sources, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :techniques, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_and_belongs_to_many :themes, -> { distinct }, after_add: :touch_updated_at, after_remove: :touch_updated_at
  has_many :appraisals
  has_many :attachments, as: :attache

  scope :no_photo_front, -> { where(photo_front: nil)}

  accepts_nested_attributes_for :artists
  accepts_nested_attributes_for :appraisals

  normalize_attributes :location, :stock_number, :alt_number_1, :alt_number_2, :alt_number_3, :photo_front, :photo_back, :photo_detail_1, :photo_detail_2, :title, :print, :grade_within_collection, :entry_status, :abstract_or_figurative, :location_detail

  mount_uploader :photo_front, PictureUploader
  mount_uploader :photo_back, PictureUploader
  mount_uploader :photo_detail_1, PictureUploader
  mount_uploader :photo_detail_2, PictureUploader

  attr_localized :frame_height, :frame_width, :frame_depth, :frame_diameter, :height, :width, :depth, :diameter

  settings index: { number_of_shards: 5 } do
    mappings do
      indexes :abstract_or_figurative, type: 'keyword'
      indexes :description, analyzer: 'dutch', index_options: 'offsets'
      indexes :grade_within_collection, type: 'keyword'
      indexes :location_raw, type: 'keyword'
      indexes :location_floor_raw, type: 'keyword'
      indexes :location_detail_raw, type: 'keyword'
      indexes :object_format_code, type: 'keyword'
      indexes :report_val_sorted_artist_ids, type: 'keyword'
      indexes :report_val_sorted_object_category_ids, type: 'keyword'
      indexes :report_val_sorted_technique_ids, type: 'keyword'
      indexes :title, analyzer: 'dutch', index_options: 'offsets'
    end
  end

  index_name "works-a"

  def photos?
    photo_front? or photo_back? or photo_detail_1? or photo_detail_2?
  end

  def title_rendered
    title_nil = title.nil? or title.to_s.strip.empty?
    if title_unknown and title_nil
      return "Zonder titel"
    elsif title_nil
      return "Nog geen titel"
    else
      return read_attribute(:title)
    end
  end

  def name(options={})
    "#{artist_name_rendered} - #{title_rendered}"
  end

  def location_raw
    location if location && location.to_s.strip != ""
  end
  def location_floor_raw
    location_floor if location_floor && location_floor.to_s.strip != ""
  end
  def location_detail_raw
    location_detail if location_detail && location_detail.to_s.strip != ""
  end

  def abstract_or_figurative_rendered
    if abstract_or_figurative?
      return abstract_or_figurative == "abstract" ? "Abstract" : "Figuratief"
    end
  end

  def locality_geoname_name
    gs = GeonameSummary.where(geoname_id: locality_geoname_id).first
    return gs.label if gs
  end

  def purchased_on= date
    if date.is_a? String
      begin
        date = date.to_date
      rescue ArgumentError
      end
    end
    if date.is_a? Date or date.is_a? Time or date.is_a? DateTime
      begin
        self.update_column(:purchased_on, date)
        self.update_column(:purchase_year, date.year)
      rescue ArgumentError
      end
    end
    if date.is_a? Numeric or date.is_a? String
      new_date = date.to_i
      if new_date > 1900 and new_date < 2100
        self.update_column(:purchase_year, date)
      end
    end
  end

  def cluster_name= name
    if name == "" or name == nil
      self.cluster = nil
    else
      clust = self.collection.clusters_including_parent_clusters.find_by_case_insensitive_name(name.strip).first
      self.cluster = clust
      if self.cluster.nil?
        self.cluster = self.collection.clusters.new(name: name.strip)
      end
    end
  end

  def cluster_name
    if cluster
      cluster.name
    end
  end

  def sync_purchase_year
    if purchased_on
      self.purchase_year = purchased_on.year
    end
  end

  def purchased_on_with_fallback
    return purchased_on if purchased_on
    return purchase_year if purchase_year
  end

  def geoname_ids
    ids = []
    artists.each do |artist|
      ids += artist.geoname_ids
    end
    ids << locality_geoname_id if locality_geoname_id
    GeonameSummary.where(geoname_id: ids).with_parents.select(:geoname_id).collect{|a| a.geoname_id}
  end

  def cache_key(additional=[])
    [self, "v1.8"]+additional
  end

  def artist_name_rendered_without_years_nor_locality
    artist_name_rendered({include_years: false, include_locality: false})
  end

  def artist_name_rendered(options={})
    if options[:rebuild]
      self.artist_name_rendered = artists.order_by_name.distinct.collect{|a| a.name(options) if a.name(options).to_s.strip != ""}.compact.to_sentence
      if artist_unknown and (artist_name_rendered.nil? or artist_name_rendered.empty?)
        self.artist_name_rendered = "Onbekend"
      end
      return artist_name_rendered
    else
      rv = read_attribute(:artist_name_rendered)
      rv = rv.to_s.gsub(/\s\(([\d\-\s]*)\)/,"") if options[:include_years] == false
      rv
    end
  end

  def update_artist_name_rendered!
    self.update_column(:artist_name_rendered, artist_name_rendered({rebuild:true}))
  end

  def signature_rendered
    if no_signature_present and signature_comments.to_s.strip.empty?
      "Niet gesigneerd"
    else
      signature_comments unless signature_comments.to_s.strip.empty?
    end
  end

  def object_creation_year_rendered
    if object_creation_year_unknown and object_creation_year.nil?
      "Onbekend"
    else
      object_creation_year
    end
  end

  def alt_numbers
    nrs = [alt_number_1, alt_number_2, alt_number_3]
    nrs if nrs.count > 0
  end

  def condition_work_rendered
    rv = []
    rv.push(condition_work.name) if condition_work
    rv.push(damage_types.collect{|a| a.name}.join(", ")) if damage_types.count > 0
    rv.push(condition_work_comments) if condition_work_comments?
    rv = rv.join("; ")
    return rv if rv != ""
  end

  def condition_frame_rendered
    rv = []
    rv.push(condition_frame.name) if condition_frame
    rv.push(frame_damage_types.collect{|a| a.name}.join(", ")) if frame_damage_types.count > 0
    rv.push(condition_frame_comments) if condition_frame_comments?
    rv = rv.join("; ")
    return rv if rv != ""
  end
  def purchase_price_symbol
    purchase_price_currency ? purchase_price_currency.symbol : "€"
  end

  def dimension_to_s value, nil_value=nil
    value ? number_with_precision(value, precision: 5, significant: true, strip_insignificant_zeros: true) : nil_value
  end

  def whd_to_s width=nil, height=nil, depth=nil, diameter=nil
    whd_values = [width, height, depth].collect{|a| dimension_to_s(a)}.compact
    rv = whd_values.join(" x ")
    if whd_values.count > 0
      legend = []
      legend << "b" unless width.to_s == ""
      legend << "h" unless height.to_s == ""
      legend << "d" unless depth.to_s == ""
      rv = "#{rv} (#{legend.join("x")})"
    end
    rv = [rv, "⌀ #{dimension_to_s(diameter)}"].compact.join("; ") if dimension_to_s(diameter)
    rv
  end

  def main_collection
    read_attribute(:main_collection) ? true : nil
  end

  def frame_size
    whd_to_s(frame_width, frame_height, frame_depth, frame_diameter)
  end

  def work_size
    whd_to_s(width, height, depth, diameter)
  end

  def hpd_height
    frame_height? ? frame_height : height
  end
  def hpd_width
    frame_width? ? frame_width : width
  end
  def hpd_depth
     frame_depth? ? frame_depth : depth
  end
  def hpd_diameter
    frame_diameter? ? frame_diameter : diameter
  end
  def hpd_keywords
     object_categories.collect{|a| a.name}.join(",")
  end
  def hpd_materials
     techniques.collect{|a| a.name}.join(",")
  end
  def hpd_condition
    condition_work_rendered
  end
  def base_file_name
    stock_number? ? stock_number : "AUTO_DB_ID_#{id}"
  end
  def hpd_photo_file_name
    "#{base_file_name}_front.jpg"
  end
  def hpd_comments
  end
  def hpd_contact
  end

  def next
    all_works = collection.works.select(:id).order([:stock_number,:id]).collect{|a| a.id}
    next_work_id = all_works[all_works.index(self.id)+1]
    next_work_id ? Work.find(next_work_id) : Work.find(all_works[0])
  end

  def set_empty_values_to_nil
    #especially important for elasticsearch filtering on empty values!
    if grade_within_collection.is_a? String and grade_within_collection.strip == ""
      self.grade_within_collection=nil
    end
  end

  def collection_name_extended
    self.collection.collection_name_extended
  end

  def as_indexed_json(*)
    self.as_json(
      include: {
        sources: { only: [:id, :name]},
        style: { only: :name},
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
        :geoname_ids,
        :title_rendered,
        :artist_name_rendered,
        :report_val_sorted_artist_ids,
        :report_val_sorted_object_category_ids,
        :report_val_sorted_technique_ids,
        :report_val_sorted_theme_ids,
        :location_raw,
        :object_format_code
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
  def object_format_code
    size = [hpd_height,hpd_width,hpd_depth,hpd_diameter].compact.max
    ofc = nil
    if size
      if size < 30
        ofc = :xs
      elsif size < 50
        ofc = :s
      elsif size < 80
        ofc = :m
      elsif size < 120
        ofc = :l
      elsif size >= 120
        ofc = :xl
      end
    end
    return ofc
  end

  def add_lognoteline note
    self.lognotes = self.lognotes.to_s + "\n#{note}"
  end

  def title= titel
    if titel.to_s.strip == ""
      write_attribute(:title, nil)
    elsif titel.to_s.strip.downcase == "zonder titel"
      write_attribute(:title_unknown, true)
    else
      write_attribute(:title, titel)
    end
  end

  def object_creation_year= year
    if year.to_i > 0
      write_attribute(:object_creation_year, year)
    elsif ["geen jaar", "zonder jaartal"].include? year.to_s
      write_attribute(:object_creation_year_unknown, true)
    end
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

  def update_latest_appraisal_data!
    latest_appraisal = appraisals.descending_appraisal_on.first
    if latest_appraisal
      self.market_value = latest_appraisal.market_value
      self.replacement_value = latest_appraisal.replacement_value
      self.price_reference = latest_appraisal.reference
      self.valuation_on = latest_appraisal.appraised_on
    else
      self.market_value = nil
      self.replacement_value = nil
      self.price_reference = nil
      self.valuation_on = nil
    end
    self.save
  end

  def enforce_nil_or_true
    self.main_collection = nil if self.main_collection == false
  end

  def touch_updated_at(objekt)
    self.touch if persisted?
  end

  class << self
    def fast_aggregations attributes
      rv = {}
      attributes.each do |attribute|
        rv[attribute] ||= {}
        if column_names.include? attribute.to_s
          self.select(attribute).group(attribute).collect{|a| a.send(attribute)}.each do |a|
            value = (a ? a : :not_set)
            if value.is_a? String
              if attribute == :grade_within_collection
                value = value[0]
              end
              value = value.downcase.to_sym
            end
            rv[attribute][value] ||= {count: 999999, name: value }
          end
        elsif column_names.include? "#{attribute}_id"
          ids = self.group("#{attribute}_id").select("#{attribute}_id").collect{|a| a.send("#{attribute}_id")}
          if ids.compact.length < ids.length
            rv[attribute][:not_set] ||= {count: 999999, name: :not_set }
          end
          attribute.to_s.classify.constantize.where(id: [ids]).each do |a|
            rv[attribute][a] ||= {count: 10000, name: a.name }
          end
        elsif attribute == :geoname_ids
          ids = self.group(:locality_geoname_id).select(:locality_geoname_id).collect{|a| a.locality_geoname_id}.compact.uniq
          artists = Artist.where(id: self.joins(:artists).select("artist_id AS id").collect{|a| a.id}).distinct
          artists.each do |artist|
            ids += artist.geoname_ids
          end
          ids = ids.compact.uniq
          GeonameSummary.where(geoname_id: ids).with_parents.each do |geoname|
            rv[attribute][geoname] = {count: 10000, name: geoname.name}
          end
        else
          ids = self.left_outer_joins(attribute).select("#{attribute}.id AS id").distinct.collect(&:id)
          if ids.compact.length < ids.length
            rv[attribute][:not_set] ||= {count: 999999, name: :not_set }
          end
          attribute.to_s.classify.constantize.where(id: [ids]).each do |a|
            rv[attribute][a] ||= {count: 999999, name: a.name }
          end
        end
      end
      rv
    end

    def aggregations attributes
      rv = {}
      self.all.each do |work|
        attributes.each do |attribute|
          rv[attribute] ||= {}
          values = work.send(attribute)
          if values.is_a? ActiveRecord::Associations::CollectionProxy
            values.each do |value|
              rv[attribute][value] ||= {count: 0, name: value.name}
              rv[attribute][value][:count] += 1
            end
            if values.empty?
              rv[attribute][:not_set] ||= {count: 0, name: :not_set }
              rv[attribute][:not_set][:count] += 1
            end
          else
            value = values
            if value.is_a? String
              if attribute == :grade_within_collection
                value = value[0]
              end
              value = value.downcase.to_sym
            end
            value = :not_set if value.nil?
            rv[attribute][value] ||= {count: 0, name: value }
            rv[attribute][value][:count] += 1
          end
        end
      end
      rv
    end

    def collect_locations
      rv = {}
      self.group(:location).count.sort{|a,b| a[0].to_s.downcase<=>b[0].to_s.downcase }.each{|a| rv[a[0]] = {count: a[1], subs:[]} }
      rv
    end


    def update_artist_name_rendered!
      self.all.each{|w| w.update_artist_name_rendered!; w.save if w.changes != {}}
    end
    def human_attribute_name_overridden(field, collection)
      if collection
        return collection.label_override_work_alt_number_1_with_inheritance if collection.label_override_work_alt_number_1_with_inheritance and field.to_sym == :alt_number_1
        return collection.label_override_work_alt_number_2_with_inheritance if collection.label_override_work_alt_number_2_with_inheritance and field.to_sym == :alt_number_2
        return collection.label_override_work_alt_number_3_with_inheritance if collection.label_override_work_alt_number_3_with_inheritance and field.to_sym == :alt_number_3
      end
      Work.human_attribute_name(field)
    end
    def to_workbook(fields=[:id,:title_rendered], collection = nil)
      w = Workbook::Book.new([fields.collect{|a| Work.human_attribute_name_overridden(a, collection)}])
      self.all.each do |work|
        values = fields.collect do |field|
          value = work.send(field)
          if value.class == PictureUploader
            value = value.file ? value.file.filename : nil
          end
          if [Collection,User,Currency,Source,Style,Medium,Condition,Subset,Placeability,Cluster,FrameType].include? value.class
            value = value.name
          end
          if value.is_a? Artist::ActiveRecord_Associations_CollectionProxy
            value = work.artist_name_rendered
          end
          if value.class.to_s.match(/ActiveRecord\_Associations\_CollectionProxy/)
            if value.first.is_a? PaperTrail::Version
              value = "Versie"
            else
              value = value.collect{|a| a.name}.join(", ")
            end
          end
          if value.is_a? Hash
            value = value.to_s
          end

          value
        end
        w.sheet.table << values
      end
      return w
    end
  end
end
