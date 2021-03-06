# frozen_string_literal: true

require "rails_helper"

RSpec.describe RkdArtist, type: :model do
  describe "#to_artist_params" do
    it "extracts correctly artist params rkd_api_response1" do
      rkd_id = 123123
      rkd_artist = RkdArtist.create(rkd_id: rkd_id, api_response_source_url: "https://api.rkd.nl/api/record/artists/#{rkd_id}?format=json", api_response: JSON.parse(File.open(File.join(Rails.root, "spec", "fixtures", "rkd_api_response1.json")).read))
      expected = {
        date_of_birth: nil,
        date_of_death: nil,
        year_of_birth: 1952,
        year_of_death: nil,
        place_of_birth: "Den Haag",
        place_of_death: nil,
        last_name: "Haas",
        first_name: " Konijn",
        place_of_death_geoname_id: nil,
        place_of_birth_geoname_id: nil,
        rkd_artist_id: 123123
      }
      assert_equal(expected, rkd_artist.to_artist_params)
    end
    it "extracts correctly artist params rkd_api_response2" do
      rkd_id = 123123
      rkd_artist = RkdArtist.create(rkd_id: rkd_id, api_response_source_url: "https://api.rkd.nl/api/record/artists/#{rkd_id}?format=json", api_response: JSON.parse(File.open(File.join(Rails.root, "spec", "fixtures", "rkd_api_response2.json")).read))
      expected = {
        date_of_birth: Date.new(1903, 10, 4),
        date_of_death: Date.new(1975, 1, 15),
        year_of_birth: 1903,
        year_of_death: 1975,
        place_of_birth: "Nieuwendam (Amsterdam)",
        place_of_death: "Amsterdam",
        last_name: "Zwartvrouw",
        first_name: " Muhly",
        place_of_death_geoname_id: nil,
        place_of_birth_geoname_id: nil,
        rkd_artist_id: 123123
      }
      assert_equal(expected, rkd_artist.to_artist_params)
    end
  end
end
