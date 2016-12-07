class Cluster < ApplicationRecord
  has_many :works
  belongs_to :collection

  scope :order_by_name, -> { order(:name) }

  include NameId

end
