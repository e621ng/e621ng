# frozen_string_literal: true

class DbExportsController < ApplicationController
  before_action :validate_exports_enabled

  def index
    @exports = DbExport.order(:name)

    respond_to do |format|
      format.html
      format.json { render json: @exports.map { |export| export_json(export) } }
    end
  end

  private

  def export_json(export)
    {
      name: export.name,
      file_name: export.file_name,
      file_size: export.file_size,
      updated_at: export.updated_at,
      url: export.url,
    }
  end

  def validate_exports_enabled
    raise ActiveRecord::RecordNotFound unless Danbooru.config.db_export_enabled?
  end
end
