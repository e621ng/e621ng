# frozen_string_literal: true

class AddSubmittedReplacementsCountToUserStatuses < ActiveRecord::Migration[8.1]
  def change
    add_column :user_statuses, :post_replacement_submitted_count, :integer, null: false, default: 0
  end
end
