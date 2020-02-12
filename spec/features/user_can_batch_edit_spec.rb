# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.feature "Batch Editor", type: :feature do
  include ActiveSupport::Testing::TimeHelpers
  include FeatureHelper

  scenario "move work to sub-collection in cluster" do
    login "qkunst-test-advisor@murb.nl"

    click_on "Collecties"
    if page.body.match("id=\"list-to-filter\"")
      within "#list-to-filter" do
        click_on "Collection 1"
      end
    end
    click_on "Toon alle 3 werken"
    work_to_edit1 = works(:work1)
    work_to_edit2 = works(:work2)
    work_to_edit3 = works(:work5)

    expect(work_to_edit1.cluster).not_to eq(work_to_edit2.cluster)

    check "selected_works_#{work_to_edit1.id}"
    check "selected_works_#{work_to_edit2.id}"
    click_on "Batch Editor"

    new_cluster_name = "My first batch cluster"
    fill_in_with_strategy(:cluster_name, new_cluster_name, :REPLACE)
    click_on "2 werken bijwerken"

    work_to_edit1 = Work.find(work_to_edit1.id)
    work_to_edit2 = Work.find(work_to_edit2.id)

    expect(work_to_edit1.cluster).to eq(work_to_edit2.cluster)
    expect(work_to_edit1.cluster.name).to eq(new_cluster_name)

    within "#responsive-filter" do
      click_on "Reset filters"
    end
    check "selected_works_#{work_to_edit1.id}"
    check "selected_works_#{work_to_edit3.id}"
    click_on "Batch Editor"

    fill_in_with_strategy(:cluster_name, new_cluster_name, :APPEND)
    click_on "2 werken bijwerken"

    work_to_edit1 = Work.find(work_to_edit1.id)
    work_to_edit3 = Work.find(work_to_edit3.id)

    expect(work_to_edit1.cluster.name).to eq("#{new_cluster_name} #{new_cluster_name}")
    expect(work_to_edit3.cluster.name).to eq("cluster2 #{new_cluster_name}")
  end

  scenario "appraise works" do
    travel 1.day do
      work_to_edit1 = works(:work1)
      work_to_edit2 = works(:work2)

      login "qkunst-test-appraiser@murb.nl"

      click_on "Collecties"
      if page.body.match("id=\"list-to-filter\"")
        within "#list-to-filter" do
          click_on "Collection 1"
        end
      end
      click_on "Toon alle 3 werken"

      expect(work_to_edit1.cluster).not_to eq(work_to_edit2.cluster)

      check "selected_works_#{work_to_edit1.id}"
      check "selected_works_#{work_to_edit2.id}"
      click_on "Batch Editor"
      select("400-500")
      select(I18n.t("helpers.batch.strategies.REPLACE"), from: "work_appraisals_attributes_0_update_replacement_value_range_strategy")

      click_on "2 werken bijwerken"
      expect(page.body).to match("Gewaardeerd op moet opgegeven zijn")

      expect(work_to_edit1.appraisals.where(created_at: (5.minutes.ago..5.minutes.from_now)).count).to eq(0)
      expect(work_to_edit2.appraisals.where(created_at: (5.minutes.ago..5.minutes.from_now)).count).to eq(0)

      click_on "Collecties"
      if page.body.match("id=\"list-to-filter\"")
        within "#list-to-filter" do
          click_on "Collection 1"
        end
      end
      click_on "Toon alle 3 werken"

      expect(work_to_edit1.cluster).not_to eq(work_to_edit2.cluster)

      check "selected_works_#{work_to_edit1.id}"
      check "selected_works_#{work_to_edit2.id}"
      click_on "Batch Editor"
      select("400-500")
      select(I18n.t("helpers.batch.strategies.REPLACE"), from: "work_appraisals_attributes_0_update_market_value_range_strategy")
      fill_in("Gewaardeerd op", with: "2019-01-01")
      select(I18n.t("helpers.batch.strategies.REPLACE"), from: "work_appraisals_attributes_0_update_appraised_on_strategy")

      click_on "2 werken bijwerken"

      expect(page.body).to match("De onderstaande 2 werken zijn bijgewerkt")

      work_to_edit1 = Work.find(work_to_edit1.id)
      work_to_edit2 = Work.find(work_to_edit2.id)

      expect(work_to_edit1.appraisals.where(created_at: (5.minutes.ago..5.minutes.from_now)).count).to eq(1)
      expect(work_to_edit2.appraisals.where(created_at: (5.minutes.ago..5.minutes.from_now)).count).to eq(1)

      work_to_edit1.reload

      expect(work_to_edit1.market_value_range.min).to eq(400)
      expect(work_to_edit2.market_value_range.min).to eq(400)
      expect(work_to_edit1.market_value_range.max).to eq(500)
      expect(work_to_edit2.market_value_range.max).to eq(500)
    end
  end

  scenario "modify other attributes (happy flow)" do
    work_to_edit1 = works(:work1)
    work_to_edit2 = works(:work2)

    login "qkunst-test-appraiser@murb.nl"

    click_on "Collecties"
    if page.body.match("id=\"list-to-filter\"")
      within "#list-to-filter" do
        click_on "Collection 1"
      end
    end
    click_on "Toon alle 3 werken"

    check "selected_works_#{work_to_edit1.id}"
    check "selected_works_#{work_to_edit2.id}"
    click_on "Batch Editor"

    new_values = {
      location: "New location",
      minimum_bid: 0.12,
      selling_price: 12345.01,
      purchase_price: 853.41,
      purchased_on: "2012-05-03".to_date
    }

    new_values.each do |key, value|
      fill_in_with_strategy(key, value, :REPLACE)
    end

    click_on "2 werken bijwerken"

    work_to_edit1.reload

    new_values.each do |key, value|
      expect(work_to_edit1.send(key)).to eq(value)
    end
  end

  scenario "[cluster batch editor, remove?] move work to subcollection in using the cluster-batch editor" do
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


  def fill_in_with_strategy field, value, strategy=IGNORE
    fill_in(I18n.t("activerecord.attributes.work.#{field}"), with: value)
    select(I18n.t("helpers.batch.strategies.#{strategy}"), from: "work_update_#{field}_strategy")
  end
end
