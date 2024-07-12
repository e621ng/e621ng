# frozen_string_literal: true

class AddUserStatusesTicketCount < ActiveRecord::Migration[7.0]
  def change
    add_column :user_statuses, :ticket_count, :integer, default: 0, null: false
  end
end
