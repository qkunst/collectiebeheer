class Appraisal < ApplicationRecord
  belongs_to :work
  belongs_to :user

  after_destroy :update_work_appraisal_data!

  validates_presence_of :appraised_on

  include ActionView::Helpers::NumberHelper

  accepts_nested_attributes_for :work

  scope :descending_appraisal_on, -> { order("appraisals.appraised_on is null, appraisals.appraised_on desc, appraisals.id desc") }

  def update_work_appraisal_data!
    if work
      work.update_latest_appraisal_data!
    end
  end

  def name
    mw = market_value ? "MW #{number_to_currency(market_value)}" : nil
    vw = replacement_value ? "VW #{number_to_currency(replacement_value)}" : nil
    "#{appraised_on ? I18n.l(appraised_on) : 'onbekende datum'} (by #{appraised_by}): #{[mw,vw].compact.join("; ")}"
  end
end
