# frozen_string_literal: true

class DbExportsController < ApplicationController
  before_action :validate_exports_enabled
  before_action :member_only, only: %i[favorites votes]

  def index
    @exports = DbExport.order(:name)

    respond_to do |format|
      format.html
      format.json { render json: @exports.map { |export| export_json(export) } }
    end
  end

  def favorites
    user = CurrentUser.user
    stream_personal_csv(
      "SELECT id, post_id, created_at FROM favorites WHERE user_id = #{user.id} ORDER BY id DESC",
      "favorites-#{user.name}-#{Date.current}.csv",
    )
  end

  def votes
    user = CurrentUser.user
    stream_personal_csv(
      "SELECT id, post_id, score, created_at FROM post_votes WHERE user_id = #{user.id} ORDER BY id DESC",
      "votes-#{user.name}-#{Date.current}.csv",
    )
  end

  private

  def stream_personal_csv(query, filename)
    headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: filename)
    headers["Content-Type"] = "text/csv"

    conn = ActiveRecord::Base.connection.raw_connection
    self.response_body = Enumerator.new do |yielder|
      conn.copy_data("COPY (#{query}) TO STDOUT WITH CSV HEADER") do
        while (row = conn.get_copy_data)
          yielder << row
        end
      end
    end
  end

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
