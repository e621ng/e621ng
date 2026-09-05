# frozen_string_literal: true

# Each export is public: the SELECT projection lists only publicly visible
# columns, and hidden/deleted rows are filtered out.
class DbExportJob < ApplicationJob
  sidekiq_options queue: "low_prio"

  def self.read_export_sql(name)
    contents = Rails.root.join("db", "exports", "#{name}.sql").read
    -> { contents }
  end

  EXPORTS = {
    "artists" => {
      query: read_export_sql("artists"),
      connection: nil,
    },
    "bulk_update_requests" => {
      query: read_export_sql("bulk_update_requests"),
      connection: nil,
    },
    "eris" => {
      query: read_export_sql("eris"),
      connection: "eris",
    },
    "pools" => {
      query: read_export_sql("pools"),
      connection: nil,
    },
    "post_replacements" => {
      query: read_export_sql("post_replacements"),
      connection: nil,
    },
    "post_versions" => {
      query: read_export_sql("post_versions"),
      connection: nil,
    },
    "posts" => {
      query: read_export_sql("posts"),
      connection: nil,
    },
    "tag_aliases" => {
      query: read_export_sql("tag_aliases"),
      connection: nil,
    },
    "tag_implications" => {
      query: read_export_sql("tag_implications"),
      connection: nil,
    },
    "tags" => {
      query: read_export_sql("tags"),
      connection: nil,
    },
    "wiki_pages" => {
      query: read_export_sql("wiki_pages"),
      connection: nil,
    },
  }.freeze

  def perform
    return unless Danbooru.config.db_export_enabled?

    EXPORTS.each do |name, config|
      generate_export(name, config)
    end
  end

  private

  def with_connection(name)
    raise(LocalJumpError, "block required") unless block_given?
    case name
    when nil
      conn = ActiveRecord::Base.connection.raw_connection
      conn.exec("SET statement_timeout = 0")
      begin
        yield(conn)
      ensure
        conn&.exec("RESET statement_timeout")
      end
    else
      config = ActiveRecord::Base.configurations.configs_for(env_name: name).first&.configuration_hash
      raise(ArgumentError, "unknown connection: #{name}") if config.blank?
      conn = PG.connect(host: config[:host], port: config[:port], user: config[:username], password: config[:password], dbname: config[:database])
      conn.exec("SET statement_timeout = 0")
      begin
        yield(conn)
      ensure
        conn&.close
      end
    end
  end

  def generate_export(name, config)
    Rails.logger.info("DbExportJob: Generating #{name} export")

    file = Tempfile.new(["#{name}-export", ".csv.gz"], binmode: true)
    with_connection(config[:connection]) { |conn| write_csv_gz(conn, config[:query].call, file) }
    file.rewind

    checksum = Digest::SHA256.file(file.path).hexdigest
    Danbooru.config.storage_manager.store_db_export(file, "#{name}.csv.gz")
    record_export(name, file.size, checksum)

    Rails.logger.info("DbExportJob: Finished #{name} export (#{ActiveSupport::NumberHelper.number_to_human_size(file.size)})")
  rescue StandardError => e
    Rails.logger.error("DbExportJob: Failed to generate #{name} export: #{e.message}")
    ActiveRecord::Base.connection.reconnect!
  ensure
    file&.close!
  end

  def write_csv_gz(conn, query, file)
    gz = Zlib::GzipWriter.new(file)
    conn.copy_data("COPY (#{query}) TO STDOUT WITH CSV HEADER") do
      while (row = conn.get_copy_data)
        gz.write(row)
      end
    end
  ensure
    gz&.finish
  end

  def record_export(name, file_size, checksum)
    export = DbExport.find_or_initialize_by(name: name)
    export.update!(file_size: file_size, checksum: checksum, updated_at: Time.current)
  end
end
