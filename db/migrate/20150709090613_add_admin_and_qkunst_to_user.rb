# frozen_string_literal: true

class AddAdminAndQkunstToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :admin, :boolean
    add_column :users, :qkunst, :boolean
  end
end
