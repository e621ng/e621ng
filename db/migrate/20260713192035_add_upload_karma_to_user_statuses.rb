# frozen_string_literal: true

class AddUploadKarmaToUserStatuses < ActiveRecord::Migration[8.1]
  def change
    add_column :user_statuses, :upload_karma, :integer, default: 0, null: false
  end
end
