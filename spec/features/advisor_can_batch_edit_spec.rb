# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.feature "AdvisorCanBatchEdit", type: :feature do
  include FeatureHelper

  scenario "move work to subcollection in cluster" do
    login "qkunst-test-advisor@murb.nl"

    click_on "Collecties"
    if page.body.match("id=\"list-to-filter\"")
      within "#list-to-filter" do
        click_on "Collection 1"
      end
    end
    click_on "Toon alle 3 werken"
    work_to_add_to_cluster = works(:work1)
    check "selected_works_#{work_to_add_to_cluster.id}"
    click_on "Nieuw cluster"
    fill_in("Clusternaam", with: "My first batch cluster")
    click_on "Pas 1 werk aan (vervangt)"
    check "selected_works_#{work_to_add_to_cluster.id}"
    click_on "Collectie"
    select "Collection with works child (sub of Collection 1 >> colection with works)"
    click_on "Pas 1 werk aan (vervangt)"
    click_on "Work1"
    expect(page).to have_content("Collection with works child (sub of Collection 1 >> colection with works)")
    expect(page).to have_content("My first batch cluster")
  end
end
