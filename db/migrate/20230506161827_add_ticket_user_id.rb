# frozen_string_literal: true

class AddTicketUserId < ActiveRecord::Migration[7.0]
  def change
    add_column :tickets, :accused_id, :integer
    add_foreign_key :tickets, :users, column: :accused_id
  end
end
