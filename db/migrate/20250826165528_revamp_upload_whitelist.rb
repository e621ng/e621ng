# frozen_string_literal: true

class RevampUploadWhitelist < ActiveRecord::Migration[7.1]
  def up
    UploadWhitelist.without_timeout do
      add_column :upload_whitelists, :domain, :string
      add_column :upload_whitelists, :path, :string, default: "\/.+" # rubocop:disable Style/RedundantStringEscape

      change_column_default :upload_whitelists, :pattern, ""
    end
  end

  def down
    UploadWhitelist.without_timeout do
      remove_column :upload_whitelists, :domain
      remove_column :upload_whitelists, :path

      change_column_default :upload_whitelists, :pattern, nil
    end
  end
end
