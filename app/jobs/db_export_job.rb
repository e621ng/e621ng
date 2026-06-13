# frozen_string_literal: true

# Each export is public: the SELECT projection lists only publicly visible
# columns, and hidden/deleted rows are filtered out.
class DbExportJob < ApplicationJob
  queue_as :low_prio

  EXPORTS = {
    "artists" => {
      query: proc do
        <<~SQL.squish
          SELECT
            artists.id,
            artists.name,
            artists.other_names,
            artists.group_name,
            artists.linked_user_id,
            artists.is_active,
            artists.is_locked,
            artists.creator_id,
            artists.created_at,
            artists.updated_at,
            COALESCE(array_to_string(array_agg(artist_urls.url ORDER BY artist_urls.id) FILTER (WHERE artist_urls.is_active = TRUE), ' '), '') AS active_urls,
            COALESCE(array_to_string(array_agg(artist_urls.url ORDER BY artist_urls.id) FILTER (WHERE artist_urls.is_active = FALSE), ' '), '') AS inactive_urls
          FROM artists
          LEFT OUTER JOIN artist_urls ON artist_urls.artist_id = artists.id
          GROUP BY artists.id
          ORDER BY artists.id
        SQL
      end,
    },
    "bulk_update_requests" => {
      query: proc do
        <<~SQL.squish
          SELECT
            bulk_update_requests.id,
            bulk_update_requests.user_id,
            bulk_update_requests.forum_topic_id,
            bulk_update_requests.forum_post_id,
            bulk_update_requests.script,
            bulk_update_requests.status,
            bulk_update_requests.approver_id,
            bulk_update_requests.title,
            bulk_update_requests.created_at,
            bulk_update_requests.updated_at,
            COALESCE(votes.down, 0) AS down_votes,
            COALESCE(votes.meh, 0)  AS meh_votes,
            COALESCE(votes.up, 0)   AS up_votes
          FROM bulk_update_requests
          LEFT JOIN forum_posts ON bulk_update_requests.forum_post_id = forum_posts.id
          LEFT JOIN LATERAL (
            SELECT
              COUNT(*) FILTER (WHERE forum_post_votes.score = -1) AS down,
              COUNT(*) FILTER (WHERE forum_post_votes.score = 0)  AS meh,
              COUNT(*) FILTER (WHERE forum_post_votes.score = 1)  AS up
            FROM forum_post_votes
            WHERE forum_post_id = forum_posts.id
          ) votes ON true
          ORDER BY bulk_update_requests.id
        SQL
      end,
    },
    "pools" => {
      query: proc do
        <<~SQL.squish
          SELECT
            pools.id,
            pools.name,
            pools.created_at,
            pools.updated_at,
            pools.creator_id,
            pools.description,
            pools.is_active,
            pools.category,
            pools.post_ids
          FROM pools
          ORDER BY pools.id
        SQL
      end,
    },
    # Pending and rejected replacements are filtered out because they are not visible to regular users.
    "post_replacements" => {
      query: proc do
        <<~SQL.squish
          SELECT
            post_replacements2.id,
            post_replacements2.post_id,
            post_replacements2.creator_id,
            post_replacements2.approver_id,
            post_replacements2.file_ext,
            post_replacements2.file_size,
            post_replacements2.image_height,
            post_replacements2.image_width,
            post_replacements2.md5,
            post_replacements2.source,
            post_replacements2.file_name,
            post_replacements2.status,
            post_replacements2.reason,
            post_replacements2.created_at,
            post_replacements2.updated_at
          FROM post_replacements2
          WHERE post_replacements2.status IN ('approved', 'original')
          ORDER BY post_replacements2.id
        SQL
      end,
    },
    # Hidden versions are filtered out because they contain changes
    # that are not visible to regular users.
    "post_versions" => {
      query: proc do
        <<~SQL.squish
          SELECT
            post_versions.id,
            post_versions.post_id,
            post_versions.version,
            post_versions.tags,
            post_versions.added_tags,
            post_versions.removed_tags,
            post_versions.locked_tags,
            post_versions.added_locked_tags,
            post_versions.removed_locked_tags,
            post_versions.rating,
            post_versions.rating_changed,
            post_versions.parent_id,
            post_versions.parent_changed,
            post_versions.source,
            post_versions.source_changed,
            post_versions.description,
            post_versions.description_changed,
            post_versions.updater_id,
            post_versions.updated_at,
            post_versions.reason
          FROM post_versions
          WHERE post_versions.is_hidden = false
          ORDER BY post_versions.id
        SQL
      end,
    },
    "posts" => {
      query: proc do
        <<~SQL.squish
          SELECT
            posts.id,
            posts.uploader_id,
            posts.created_at,
            posts.md5,
            posts.source,
            posts.rating,
            posts.image_width,
            posts.image_height,
            posts.tag_string,
            posts.locked_tags,
            posts.fav_count,
            posts.file_ext,
            posts.parent_id,
            posts.change_seq,
            posts.approver_id,
            posts.file_size,
            posts.comment_count,
            posts.description,
            posts.duration,
            posts.updated_at,
            posts.is_deleted,
            posts.is_pending,
            posts.is_flagged,
            posts.score,
            posts.up_score,
            posts.down_score,
            posts.is_rating_locked,
            posts.is_status_locked,
            posts.is_note_locked,
            posts.bg_color,
            posts.last_noted_at,
            posts.last_commented_at
          FROM posts
          ORDER BY posts.id
        SQL
      end,
    },
    "tag_aliases" => {
      query: proc do
        <<~SQL.squish
          SELECT
            tag_aliases.id,
            tag_aliases.antecedent_name,
            tag_aliases.consequent_name,
            tag_aliases.created_at,
            tag_aliases.status,
            tag_aliases.forum_post_id,
            tag_aliases.forum_topic_id,
            tag_aliases.reason,
            tag_aliases.updated_at,
            tag_aliases.approver_id,
            tag_aliases.post_count,
            COALESCE(votes.down, 0) AS down_votes,
            COALESCE(votes.meh, 0)  AS meh_votes,
            COALESCE(votes.up, 0)   AS up_votes
          FROM tag_aliases
          LEFT JOIN forum_posts ON tag_aliases.forum_post_id = forum_posts.id
          LEFT JOIN LATERAL (
            SELECT
              COUNT(*) FILTER (WHERE forum_post_votes.score = -1) AS down,
              COUNT(*) FILTER (WHERE forum_post_votes.score = 0)  AS meh,
              COUNT(*) FILTER (WHERE forum_post_votes.score = 1)  AS up
            FROM forum_post_votes
            WHERE forum_post_id = forum_posts.id
          ) votes ON true
          ORDER BY tag_aliases.id
        SQL
      end,
    },
    "tag_implications" => {
      query: proc do
        <<~SQL.squish
          SELECT
            tag_implications.id,
            tag_implications.antecedent_name,
            tag_implications.consequent_name,
            tag_implications.created_at,
            tag_implications.status,
            tag_implications.forum_post_id,
            tag_implications.forum_topic_id,
            tag_implications.reason,
            tag_implications.updated_at,
            tag_implications.approver_id,
            tag_implications.descendant_names,
            COALESCE(votes.down, 0) AS down_votes,
            COALESCE(votes.meh, 0)  AS meh_votes,
            COALESCE(votes.up, 0)   AS up_votes
          FROM tag_implications
          LEFT JOIN forum_posts ON tag_implications.forum_post_id = forum_posts.id
          LEFT JOIN LATERAL (
            SELECT
              COUNT(*) FILTER (WHERE forum_post_votes.score = -1) AS down,
              COUNT(*) FILTER (WHERE forum_post_votes.score = 0)  AS meh,
              COUNT(*) FILTER (WHERE forum_post_votes.score = 1)  AS up
            FROM forum_post_votes
            WHERE forum_post_id = forum_posts.id
          ) votes ON true
          ORDER BY tag_implications.id
        SQL
      end,
    },
    "tags" => {
      query: proc do
        <<~SQL.squish
          SELECT
            tags.id,
            tags.name,
            tags.category,
            tags.post_count,
            tags.created_at,
            tags.updated_at,
            tags.is_locked
          FROM tags
          ORDER BY tags.id
        SQL
      end,
    },
    "wiki_pages" => {
      query: proc do
        <<~SQL.squish
          SELECT
            wiki_pages.id,
            wiki_pages.created_at,
            wiki_pages.updated_at,
            wiki_pages.title,
            wiki_pages.body,
            wiki_pages.creator_id,
            wiki_pages.updater_id,
            wiki_pages.is_locked,
            wiki_pages.parent
          FROM wiki_pages
          ORDER BY wiki_pages.id
        SQL
      end,
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
