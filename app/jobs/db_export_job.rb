# frozen_string_literal: true

class DbExportJob < ApplicationJob
  queue_as :default

  EXPORT_DIR = Rails.root.join("tmp/db_export")
  MAX_EXPORT_AGE = 3.days

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
    # Exposes creator_id for flag events which is normally hidden to
    # protect flagger anonymity.
    "post_events" => {
      min_level: Danbooru.config.levels["Janitor"],
      query: -> { "SELECT id, creator_id, post_id, action, extra_data, created_at FROM post_events ORDER BY id" },
    },
    # Exposes creator_id (flagger identity) which is normally hidden from
    # non-staff users and the post uploader.
    "post_flags" => {
      min_level: Danbooru.config.levels["Janitor"],
      query: -> { "SELECT id, post_id, creator_id, reason, is_resolved, is_deletion, created_at, updated_at FROM post_flags ORDER BY id" },
    },
    # Includes rejected and pending replacements that are not
    # visible to regular users.
    "post_replacements" => {
      min_level: Danbooru.config.levels["Janitor"],
      query: -> {
        <<~SQL.squish
          SELECT id, post_id, creator_id, approver_id, file_ext, file_size, image_height, image_width,
                 md5, source, file_name, status, reason, created_at, updated_at
          FROM post_replacements2 ORDER BY id
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
      query: -> { "SELECT id, created_at, updated_at, title, body, creator_id, updater_id, is_locked FROM wiki_pages WHERE is_deleted = false ORDER BY id" },
    },
    # Includes hidden comments which are only visible to staff on the site.
    "comments" => {
      min_level: Danbooru.config.levels["Janitor"],
      query: -> {
        <<~SQL.squish
          SELECT id, post_id, creator_id, body, score, do_not_bump_post, is_hidden, is_sticky,
                 warning_type, created_at, updated_at
          FROM comments ORDER BY id
        SQL
      },
    },
    # Includes hidden topics and topics from restricted forum categories.
    "forum_topics" => {
      min_level: Danbooru.config.levels["Janitor"],
      query: -> {
        <<~SQL.squish
          SELECT id, creator_id, updater_id, title, response_count, is_sticky, is_locked, is_hidden,
                 category_id, created_at, updated_at
          FROM forum_topics ORDER BY id
        SQL
      },
    },
    # Includes hidden posts and posts from restricted forum categories.
    "forum_posts" => {
      min_level: Danbooru.config.levels["Janitor"],
      query: -> {
        <<~SQL.squish
          SELECT id, topic_id, creator_id, updater_id, body, is_hidden, warning_type, created_at, updated_at
          FROM forum_posts ORDER BY id
        SQL
      },
    },
    # Includes deleted feedback which is only visible to staff on the site.
    "user_feedback" => {
      min_level: Danbooru.config.levels["Janitor"],
      query: -> { "SELECT id, user_id, creator_id, updater_id, category, body, is_deleted, created_at, updated_at FROM user_feedback ORDER BY id" },
    },
    # Contains user reports with reporter identity, report reasons,
    # and staff responses. Visibility on the site varies by ticket
    # type, but all are accessible to moderators.
    "tickets" => {
      min_level: Danbooru.config.levels["Moderator"],
      query: -> {
        <<~SQL.squish
          SELECT id, creator_id, disp_id, qtype, status, reason, report_reason,
                 response, handler_id, claimant_id, accused_id, created_at, updated_at
          FROM tickets ORDER BY id
        SQL
      },
    },
    # Excludes protected actions and admin-only actions.
    # The exclusion list is derived from ModAction::ProtectedActionKeys.
    "mod_actions" => {
      min_level: Danbooru.config.levels["Moderator"],
      query: -> {
        excluded = ModAction::ProtectedActionKeys + %w[admin_user_delete]
        excluded_sql = excluded.map { |a| "'#{a}'" }.join(", ")

        allowed_keys = ModAction::KnownActions.values.flat_map(&:keys).uniq - [:ip_addr]
        allowed_sql = allowed_keys.map { |k| "'#{k}'" }.join(", ")

        <<~SQL.squish
          SELECT id, creator_id, action,
                 (SELECT COALESCE(jsonb_object_agg(k, v), '{}'::jsonb)
                  FROM jsonb_each(values::jsonb) AS x(k, v)
                  WHERE k = ANY(ARRAY[#{allowed_sql}])) AS values,
                 created_at
          FROM mod_actions
          WHERE action NOT IN (#{excluded_sql})
          ORDER BY id
        SQL
      },
    },
  }.freeze

  def perform
    return unless Danbooru.config.db_export_enabled?

    FileUtils.mkdir_p(EXPORT_DIR)
    today = Date.current.to_s

    EXPORTS.each_key do |name|
      generate_export(name, EXPORTS[name], today)
    end

    cleanup_old_exports
    clear_cache
  end

  private

  def generate_export(name, config, date)
    gz_path = EXPORT_DIR.join("#{name}-#{date}.csv.gz")

    return if File.exist?(gz_path)

    Rails.logger.info("DbExportJob: Generating #{name} export")

    query = config[:query].call
    conn = ActiveRecord::Base.connection.raw_connection
    conn.exec("SET statement_timeout = 0")
    File.open(gz_path, "wb") do |file|
      gz = Zlib::GzipWriter.new(file)
      begin
        conn.copy_data("COPY (#{query}) TO STDOUT WITH CSV HEADER") do
          while (row = conn.get_copy_data)
            gz.write(row)
          end
        end
      ensure
        gz.close
      end
    end

    Rails.logger.info("DbExportJob: Finished #{name} export (#{ActiveSupport::NumberHelper.number_to_human_size(File.size(gz_path))})")
  rescue StandardError => e
    Rails.logger.error("DbExportJob: Failed to generate #{name} export: #{e.message}")
    FileUtils.rm_f(gz_path)
    ActiveRecord::Base.connection.reconnect!
  end

  def cleanup_old_exports
    cutoff = MAX_EXPORT_AGE.ago
    Dir.glob(EXPORT_DIR.join("*.csv.gz")).each do |file|
      File.delete(file) if File.mtime(file) < cutoff
    end
  end

  def clear_cache
    dates = (0..MAX_EXPORT_AGE.in_days.to_i).map { |d| d.days.ago.to_date.to_s }
    EXPORTS.each_key do |name|
      Rails.cache.delete("db_export:#{name}:latest")
      dates.each { |date| Rails.cache.delete("db_export:#{name}:#{date}") }
    end
  end
end
