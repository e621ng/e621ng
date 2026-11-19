# frozen_string_literal: true

module Populate
  # Replaces the synthetic version 1 of imported posts with their real edit history.
  # Needs the opt-in post_versions export; without it (and without `load: true`) this does nothing.
  class PostVersions < Importer
    SYNTHETIC = "v.version = 1 AND v.reason IS NULL AND v.updater_ip_addr = '#{LOCAL_IP}' AND v.updated_at = p.created_at".freeze

    def call
      unless Exports.loaded?("post_versions")
        return { versions: 0, posts: [] } unless options[:load]
        log "* Loading the post_versions export first (about 10 GB compressed; this takes a while)"
        ensure_loaded!("post_versions")
      end
      ensure_loaded!("posts")
      log "* Importing post versions"

      post_ids = select_ids("SELECT DISTINCT sv.post_id FROM #{SEED}.post_versions sv WHERE sv.post_id IN (#{ImportedPosts.sql(options[:post_ids])})")
      return { versions: 0, posts: [] } if post_ids.empty?

      ids = Selection.array_literal(post_ids)
      # Fresh ids must clear every production id, so nothing local can take one that is still to come.
      insert("SELECT setval(pg_get_serial_sequence('post_versions', 'id'), GREATEST((SELECT COALESCE(MAX(id), 0) FROM #{SEED}.post_versions), (SELECT COALESCE(MAX(id), 0) FROM post_versions)) + 1, false)")

      removed = insert(<<~SQL.squish)
        DELETE FROM post_versions v USING posts p
        WHERE v.post_id = p.id AND p.id = ANY(#{ids}) AND #{SYNTHETIC}
          AND NOT EXISTS (SELECT 1 FROM post_versions o WHERE o.post_id = v.post_id AND o.id <> v.id)
          AND NOT EXISTS (SELECT 1 FROM #{SEED}.post_versions sv WHERE sv.id = v.id AND sv.post_id = v.post_id)
      SQL
      moved = move_colliding_rows(ids)
      log "  synthetic versions replaced: #{removed}, local rows renumbered: #{moved.size}"

      stub_users_for("SELECT DISTINCT updater_id FROM #{SEED}.post_versions WHERE post_id = ANY(#{ids})")
      versions = insert(<<~SQL.squish)
        INSERT INTO post_versions (id, post_id, version, tags, added_tags, removed_tags, locked_tags, added_locked_tags, removed_locked_tags,
                                   rating, rating_changed, parent_id, parent_changed, source, source_changed, description, description_changed,
                                   updater_id, updated_at, reason, original_tags)
        SELECT id, post_id, COALESCE(version, 1), COALESCE(tags, ''),
               COALESCE(added_tags::text[], '{}'), COALESCE(removed_tags::text[], '{}'), locked_tags,
               COALESCE(added_locked_tags::text[], '{}'), COALESCE(removed_locked_tags::text[], '{}'),
               rating, COALESCE(rating_changed, false), parent_id, COALESCE(parent_changed, false),
               source, COALESCE(source_changed, false), description, COALESCE(description_changed, false),
               COALESCE(updater_id, 0), COALESCE(updated_at, now()), reason, COALESCE(original_tags::text[], '{}')
        FROM #{SEED}.post_versions
        WHERE post_id = ANY(#{ids})
        ON CONFLICT (id) DO NOTHING
      SQL
      log "  versions: #{versions} inserted"

      insert(<<~SQL.squish)
        UPDATE user_statuses us SET post_update_count = (SELECT COUNT(*) FROM post_versions WHERE updater_id = us.user_id)
        WHERE us.user_id IN (SELECT DISTINCT updater_id FROM post_versions WHERE post_id = ANY(#{ids}))
      SQL
      { versions: versions, posts: (post_ids + moved).uniq }
    end

    private

    # Local rows (synthetic or from local edits) sitting on an id the export is about to use.
    def move_colliding_rows(ids)
      Exports.with_timeout_off do
        connection.select_values(<<~SQL.squish).map(&:to_i)
          UPDATE post_versions v SET id = nextval(pg_get_serial_sequence('post_versions', 'id'))
          WHERE v.id IN (SELECT sv.id FROM #{SEED}.post_versions sv WHERE sv.post_id = ANY(#{ids}))
            AND NOT EXISTS (SELECT 1 FROM #{SEED}.post_versions sv WHERE sv.id = v.id AND sv.post_id = v.post_id)
          RETURNING v.post_id
        SQL
      end
    end
  end
end
