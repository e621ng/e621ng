# frozen_string_literal: true

# Each export is public: the SELECT projection lists only publicly visible
# columns, and hidden/deleted rows are filtered out.
class DbExportJob < ApplicationJob
  queue_as :low_prio

  EXPORTS = {
    "posts" => {
      query: -> {
        <<~SQL.squish
          SELECT id, uploader_id, created_at, md5, source, rating, image_width, image_height,
                 tag_string, locked_tags, fav_count, file_ext, parent_id, change_seq, approver_id,
                 file_size, comment_count, description, duration, updated_at, is_deleted, is_pending,
                 is_flagged, score, up_score, down_score, is_rating_locked, is_status_locked, is_note_locked
          FROM posts ORDER BY id
        SQL
      },
    },
    # Hidden versions are filtered out because they contain changes
    # that are not visible to regular users.
    "post_versions" => {
      query: -> {
        <<~SQL.squish
          SELECT id, post_id, version, tags, added_tags, removed_tags, locked_tags,
                 added_locked_tags, removed_locked_tags, rating, rating_changed, parent_id,
                 parent_changed, source, source_changed, description, description_changed,
                 updater_id, updated_at, reason
          FROM post_versions WHERE is_hidden = false ORDER BY id
        SQL
      },
    },
    # Pending and rejected replacements are filtered out because they are not visible to regular users.
    "post_replacements" => {
      query: -> {
        <<~SQL.squish
          SELECT id, post_id, creator_id, approver_id, file_ext, file_size, image_height, image_width,
                 md5, source, file_name, status, reason, created_at, updated_at
          FROM post_replacements2
          WHERE status IN ('approved', 'original') ORDER BY id
        SQL
      },
    },
    "tags" => {
      query: -> { "SELECT id, name, category, post_count FROM tags ORDER BY id" },
    },
    "tag_aliases" => {
      query: -> { "SELECT id, antecedent_name, consequent_name, created_at, status FROM tag_aliases ORDER BY id" },
    },
    "tag_implications" => {
      query: -> { "SELECT id, antecedent_name, consequent_name, created_at, status FROM tag_implications ORDER BY id" },
    },
    "bulk_update_requests" => {
      query: -> { "SELECT id, user_id, forum_topic_id, forum_post_id, script, status, approver_id, title, created_at, updated_at FROM bulk_update_requests ORDER BY id" },
    },
    "artists" => {
      query: -> {
        <<~SQL.squish
          SELECT a.id, a.name, a.other_names, a.group_name, a.linked_user_id,
                 a.is_active, a.is_locked, a.creator_id, a.created_at, a.updated_at,
                 array_to_string(array_agg(au.url ORDER BY au.id) FILTER (WHERE au.url IS NOT NULL), ' ') AS urls
          FROM artists a
          LEFT JOIN artist_urls au ON au.artist_id = a.id AND au.is_active = true
          GROUP BY a.id ORDER BY a.id
        SQL
      },
    },
    "pools" => {
      query: -> { "SELECT id, name, created_at, updated_at, creator_id, description, is_active, category, post_ids FROM pools ORDER BY id" },
    },
    "wiki_pages" => {
      query: -> { "SELECT id, created_at, updated_at, title, body, creator_id, updater_id, is_locked FROM wiki_pages ORDER BY id" },
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
