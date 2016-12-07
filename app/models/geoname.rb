class Geoname < ApplicationRecord
  scope :populated_places, -> { where(feature_code: ["PPL", "PPLA", "PPLA2", "PPLC", "PPLG", "PPLH", "PPLL", "PPLQ", "PPLS", "PPLX"]) }

  has_many :translations, foreign_key: :geoname_id, primary_key: :geoname_id, class_name: 'GeonameTranslation'

  def admin1
    GeonamesAdmindiv.where(admin_code: "#{country_code}.#{admin1_code}").first
  end

  def admin2
    GeonamesAdmindiv.where(admin_code: "#{country_code}.#{admin1_code}.#{admin2_code}").first
  end

  def localized_name locale=:nl
    lname = translations.locale(locale).first
    lname ? lname.label : name
  end

  def parent_description
    ([country_code]+[admin1, admin2].compact.collect{|a| a.localized_name}).join(" > ")
  end

  def find_or_create_corresponding_geoname_summary locale=:nl
    gs = GeonameSummary.find_or_initialize_by(geoname_id: geonameid, language: locale)
    gs.name = localized_name(locale)
    gs.parent_description = parent_description
    gs.type_code = feature_code
    gs.save
  end

  class << self
    def find_or_create_corresponding_geoname_summary
      self.all.each{|a| a.find_or_create_corresponding_geoname_summary}
    end
  end
end
