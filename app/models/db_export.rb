# frozen_string_literal: true

class DbExport < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  def file_name
    "#{name}.csv.gz"
  end

  def url
    Danbooru.config.storage_manager.db_export_url(file_name)
  end
end
