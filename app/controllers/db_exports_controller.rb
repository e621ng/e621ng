# frozen_string_literal: true

class DbExportsController < ApplicationController
  before_action :validate_exports_enabled
  before_action :member_only, only: [:favorites]

  def index
    @date = params[:date]
    @exports = list_exports(@date)

    respond_to do |format|
      format.html
      format.json { render json: @exports }
    end
  end

  def show
    name = params[:id]
    config = DbExportJob::EXPORTS[name]
    raise ActiveRecord::RecordNotFound unless config

    min_level = config[:min_level] || 0
    raise User::PrivilegeError if CurrentUser.user.level < min_level

    file = find_export(name, params[:date])
    raise ActiveRecord::RecordNotFound unless file

    send_file file, type: "application/gzip", disposition: "attachment"
  end

  def favorites
    user = CurrentUser.user
    query = "SELECT id, post_id, created_at FROM favorites WHERE user_id = #{user.id} ORDER BY id DESC"

    filename = "favorites-#{user.name}-#{Date.current}.csv"
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

  private

  def list_exports(date = nil)
    DbExportJob::EXPORTS.filter_map do |name, config|
      min_level = config[:min_level] || 0
      next if CurrentUser.user.level < min_level

      export_metadata(name, date)
    end
  end

  def export_metadata(name, date = nil)
    cache_key = "db_export:#{name}:#{date || 'latest'}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      file = find_export(name, date)
      next unless file

      {
        name: name,
        file_name: File.basename(file),
        file_size: File.size(file),
        updated_at: File.mtime(file),
      }
    end
  end

  def find_export(name, date = nil)
    raise ActiveRecord::RecordNotFound unless DbExportJob::EXPORTS.key?(name)

    if date.present?
      begin
        Date.parse(date)
      rescue Date::Error
        raise ActiveRecord::RecordNotFound
      end
      path = DbExportJob::EXPORT_DIR.join("#{name}-#{date}.csv.gz")
      path if File.exist?(path)
    else
      today = DbExportJob::EXPORT_DIR.join("#{name}-#{Date.current}.csv.gz")
      return today if File.exist?(today)

      yesterday = DbExportJob::EXPORT_DIR.join("#{name}-#{Date.yesterday}.csv.gz")
      yesterday if File.exist?(yesterday)
    end
  end

  def validate_exports_enabled
    raise ActiveRecord::RecordNotFound unless Danbooru.config.db_export_enabled?
  end
end
