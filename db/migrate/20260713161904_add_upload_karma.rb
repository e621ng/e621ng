# frozen_string_literal: true

class AddUploadKarma < ActiveRecord::Migration[8.1]
  def change
    add_column :user_statuses, :upload_karma, :integer, null: false, default: 0
    add_column :post_flags, :resolution, :string, null: false, default: "pending"
  end
end
