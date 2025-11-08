# frozen_string_literal: true

class CleanupUploadWhitelists < ActiveRecord::Migration[7.1]
  def up
    remove_column :upload_whitelists, :pattern, :string
    change_column_default :upload_whitelists, :path, "\\/.+"
  end

  def down
    add_column :upload_whitelists, :pattern, :string, null: false, default: ""
  end
end
