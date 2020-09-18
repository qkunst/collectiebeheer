# frozen_string_literal: true

class Attachment < ApplicationRecord
  belongs_to :attache, polymorphic: true
  has_and_belongs_to_many :works
  has_and_belongs_to_many :artists

  validates_presence_of :file

  scope :for_roles, ->(roles) { roles.include?(:admin) || roles.include?(:advisor) ? where("") : where(arel_table[:visibility].matches_any(roles.collect { |role| "%#{role}%" })) }
  scope :for_role, ->(role) { for_roles([role]) }
  scope :for_me, ->(user) { for_roles(user.roles) }
  scope :without_works, -> { left_outer_joins(:works).where(works: {id: nil})}

  mount_uploader :file, BasicFileUploader

  alias_attribute :collection, :attache

  def visibility
    read_attribute(:visibility).to_s.split(",")
  end

  def visibility= values
    write_attribute(:visibility, values.delete_if { |a| a.nil? || a.empty? }.join(","))
  end

  def append_works= works
    self.works = Work.where(id: (works.pluck(:id) + self.works.pluck(:id))).distinct
  end

  def file_name
    name? ? name : read_attribute(:file)
  end

  private

  class << self
    def move_work_attaches_to_join_table
      where(attache_type: "Work").each do |attachment|
        work = attachment.attache
        collection = work.collection
        attachment.works << work
        attachment.collection = collection
        attachment.save
      end
    end
  end
end
