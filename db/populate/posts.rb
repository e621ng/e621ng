# frozen_string_literal: true

module Populate
  # Imports posts from the exports with their production ids, a synthetic first version,
  # stub uploaders with real counts, placeholder media and an OpenSearch bulk index. Doc 44 step 3.
  class Posts < Importer
    TAG_CATEGORY_COLUMNS = TagCategory::CANONICAL_MAPPING.to_h { |name, id| [id, "tag_count_#{name.downcase}"] }.freeze

    def call
      ensure_loaded!("posts")
      Tags.new(dir: exports_dir).call if Tag.count < 1000 # categories for the tag counts

      selection = Selection.new(range: options[:range], count: options[:count], query: options[:query])
      log "* Importing posts (#{selection.conditions.presence&.join(' AND ') || 'no filter'}#{", newest #{selection.count}" if selection.count})"
      ids = time("select") { selection.with_parents(selection.ids) }
      log "  selected #{ids.size} posts"
      return { selected: 0, inserted: 0, versions: 0, media: nil } if ids.empty?

      stub_users_for("SELECT uploader_id FROM #{SEED}.posts WHERE id = ANY(#{literal(ids)}) UNION SELECT approver_id FROM #{SEED}.posts WHERE id = ANY(#{literal(ids)})")

      inserted = time("insert") { insert_posts(ids) }
      log "  posts: #{inserted.size} inserted"
      # The posts_update_change_seq trigger draws from this sequence on the updates below.
      Exports.bump_sequence!("posts", column: "change_seq")
      if inserted.any?
        time("tag counts") { update_tag_counts(inserted) }
        update_children(inserted)
      end
      versions = time("versions") { insert_versions(ids) }
      log "  versions: #{versions} inserted"
      time("user counts") { update_user_counts(ids) }

      bump_sequences!("posts", "post_versions")

      media = time("media") { generate_media(ids) } unless options.fetch(:media, :placeholder).to_s == "none"
      time("reindex") { reindex(ids) } if options.fetch(:reindex, true)

      { selected: ids.size, inserted: inserted.size, versions: versions, media: media }
    end

    private

    def literal(ids)
      Selection.array_literal(ids)
    end

    def time(label)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      log "  [#{label}: #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)}s]"
      result
    end

    def insert_posts(ids)
      Exports.with_timeout_off do
        connection.select_values(<<~SQL.squish).map(&:to_i)
          INSERT INTO posts (id, created_at, updated_at, up_score, down_score, score, source, md5, rating,
                             is_note_locked, is_rating_locked, is_status_locked, is_pending, is_flagged, is_deleted,
                             uploader_id, uploader_ip_addr, approver_id, last_noted_at, last_commented_at, fav_count, tag_string,
                             file_ext, file_size, image_width, image_height, parent_id, bit_flags, locked_tags, description,
                             comment_count, change_seq, bg_color, duration)
          SELECT p.id, p.created_at, COALESCE(p.updated_at, p.created_at), COALESCE(p.up_score, 0), COALESCE(p.down_score, 0), COALESCE(p.score, 0),
                 COALESCE(p.source, ''), p.md5, COALESCE(p.rating, 'q'),
                 COALESCE(p.is_note_locked, false), COALESCE(p.is_rating_locked, false), COALESCE(p.is_status_locked, false),
                 COALESCE(p.is_pending, false), COALESCE(p.is_flagged, false), COALESCE(p.is_deleted, false),
                 p.uploader_id, '#{LOCAL_IP}', p.approver_id, p.last_noted_at, p.last_commented_at, COALESCE(p.fav_count, 0), COALESCE(p.tag_string, ''),
                 p.file_ext, COALESCE(p.file_size, 0), COALESCE(p.image_width, 0), COALESCE(p.image_height, 0),
                 CASE WHEN p.parent_id = ANY(#{literal(ids)}) THEN p.parent_id END,
                 CASE WHEN p.file_ext IN ('webm', 'mp4', 'gif') THEN 64 ELSE 0 END,
                 p.locked_tags, COALESCE(p.description, ''), COALESCE(p.comment_count, 0), p.change_seq, p.bg_color, p.duration
          FROM #{SEED}.posts p
          WHERE p.id = ANY(#{literal(ids)})
          ON CONFLICT DO NOTHING
          RETURNING id
        SQL
      end
    end

    def update_tag_counts(ids)
      counts = TAG_CATEGORY_COLUMNS.map { |id, column| "COUNT(*) FILTER (WHERE COALESCE(t.category, 0) = #{id}) AS #{column}" }
      sets = TAG_CATEGORY_COLUMNS.values.map { |column| "#{column} = c.#{column}" }
      insert(<<~SQL.squish)
        UPDATE posts SET tag_count = c.total, #{sets.join(', ')}
        FROM (
          SELECT x.post_id, COUNT(*) AS total, #{counts.join(', ')}
          FROM (SELECT id AS post_id, unnest(string_to_array(tag_string, ' ')) AS name FROM posts WHERE id = ANY(#{literal(ids)})) x
          LEFT JOIN tags t ON t.name = x.name
          GROUP BY x.post_id
        ) c
        WHERE posts.id = c.post_id
      SQL
    end

    def update_children(ids)
      insert(<<~SQL.squish)
        UPDATE posts SET has_children = true, has_active_children = c.active
        FROM (SELECT parent_id, bool_or(NOT is_deleted) AS active FROM posts WHERE id = ANY(#{literal(ids)}) AND parent_id IS NOT NULL GROUP BY parent_id) c
        WHERE posts.id = c.parent_id
      SQL
    end

    # Version 1 as PostVersion.queue would have written it for a fresh upload.
    def insert_versions(ids)
      insert(<<~SQL.squish)
        INSERT INTO post_versions (post_id, version, tags, added_tags, removed_tags, locked_tags, added_locked_tags, removed_locked_tags,
                                   updater_id, updater_ip_addr, updated_at, rating, rating_changed, parent_id, parent_changed,
                                   source, source_changed, description, description_changed, original_tags, is_hidden)
        SELECT p.id, 1, p.tag_string, string_to_array(p.tag_string, ' '), '{}', p.locked_tags, string_to_array(COALESCE(p.locked_tags, ''), ' '), '{}',
               p.uploader_id, '#{LOCAL_IP}', p.created_at, p.rating, true, p.parent_id, true,
               p.source, true, p.description, true, '{}', false
        FROM posts p
        WHERE p.id = ANY(#{literal(ids)}) AND NOT EXISTS (SELECT 1 FROM post_versions v WHERE v.post_id = p.id)
      SQL
    end

    def update_user_counts(ids)
      insert(<<~SQL.squish)
        UPDATE user_statuses us SET
          post_count = (SELECT COUNT(*) FROM posts WHERE uploader_id = us.user_id),
          post_deleted_count = (SELECT COUNT(*) FROM posts WHERE uploader_id = us.user_id AND is_deleted),
          post_update_count = (SELECT COUNT(*) FROM post_versions WHERE updater_id = us.user_id)
        WHERE us.user_id IN (SELECT uploader_id FROM posts WHERE id = ANY(#{literal(ids)}))
      SQL
    end

    def generate_media(ids)
      Media::Placeholder.new(post_ids: ids, threads: options.fetch(:threads, Etc.nprocessors.clamp(2, 16))).call
    end

    def reindex(ids)
      log "* Indexing #{ids.size} posts and their versions"
      condition = "id = ANY(#{literal(ids)})"
      Post.document_store.import(query: condition)
      PostVersion.document_store.import(query: "post_id = ANY(#{literal(ids)})")
      Post.document_store.refresh_index!
      PostVersion.document_store.refresh_index!
    end
  end
end
