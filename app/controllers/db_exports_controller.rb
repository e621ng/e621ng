# frozen_string_literal: true

class DbExportsController < ApplicationController
  before_action :validate_exports_enabled

  def index
    @exports = DbExport.order(:name)

    respond_to do |format|
      format.html
      format.json { render json: DbExportBlueprint.render_as_hash(@exports) }
    end
  end

  private

  def validate_exports_enabled
    raise ActiveRecord::RecordNotFound unless Danbooru.config.db_export_enabled?
  end
end
