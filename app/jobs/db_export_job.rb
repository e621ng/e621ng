# frozen_string_literal: true

# Each export is public: the SELECT projection lists only publicly visible
# columns, and hidden/deleted rows are filtered out.
class DbExportJob < ApplicationJob
  queue_as :low_prio

  def self.read_export_sql(name)
    contents = Rails.root.join("db", "exports", "#{name}.sql").read
    -> { contents }
  end

  EXPORTS = {
    "artists" => {
      query: read_export_sql("artists"),
    },
    "bulk_update_requests" => {
      query: read_export_sql("bulk_update_requests"),
    },
    "pools" => {
      query: read_export_sql("pools"),
    },
    "post_replacements" => {
      query: read_export_sql("post_replacements"),
    },
    "post_versions" => {
      query: read_export_sql("post_versions"),
    },
    "posts" => {
      query: read_export_sql("posts"),
    },
    "tag_aliases" => {
      query: read_export_sql("tag_aliases"),
    },
    "tag_implications" => {
      query: read_export_sql("tag_implications"),
    },
    "tags" => {
      query: read_export_sql("tags"),
    },
    "wiki_pages" => {
      query: read_export_sql("wiki_pages"),
    },
  }.freeze

  def perform
    return unless Danbooru.config.db_export_enabled?

    EXPORTS.each do |name, config|
      generate_export(name, config)
    end
  end

  private

  def generate_export(name, config)
    Rails.logger.info("DbExportJob: Generating #{name} export")

    file = Tempfile.new(["#{name}-export", ".csv.gz"], binmode: true)
    write_csv_gz(config[:query].call, file)
    file.rewind

    Danbooru.config.storage_manager.store_db_export(file, "#{name}.csv.gz")
    record_export(name, file.size)

    Rails.logger.info("DbExportJob: Finished #{name} export (#{ActiveSupport::NumberHelper.number_to_human_size(file.size)})")
  rescue StandardError => e
    Rails.logger.error("DbExportJob: Failed to generate #{name} export: #{e.message}")
    ActiveRecord::Base.connection.reconnect!
  ensure
    file&.close!
  end

  def write_csv_gz(query, file)
    gz = Zlib::GzipWriter.new(file)
    conn = ActiveRecord::Base.connection.raw_connection
    conn.exec("SET statement_timeout = 0")
    conn.copy_data("COPY (#{query}) TO STDOUT WITH CSV HEADER") do
      while (row = conn.get_copy_data)
        gz.write(row)
      end
    end
  ensure
    conn&.exec("RESET statement_timeout")
    gz&.finish
  end

  def record_export(name, file_size)
    export = DbExport.find_or_initialize_by(name: name)
    export.update!(file_size: file_size, updated_at: Time.current)
  end
end
