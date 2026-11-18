# frozen_string_literal: true

# Copies deletion flags out of post_flags into post_deletions and re-anchors their appeals.
#
# Idempotent: run once after the migration, before the app servers restart, and again after,
# to pick up deletion flags written by old servers in between. The deletion flags themselves
# are left in place; a later fix removes them.
module Fixes
  class BackfillPostDeletions
    UNDELETED_EVENT = 1

    def self.run
      ApplicationRecord.without_timeout do
        step("Copied deletion flags", copy_sql)
        step("Marked undeleted", reconcile_sql)
        step("Stamped undeleters", undeleter_sql)
        step("Remapped appeals", appeals_sql)
        step("Orphaned appeals (post destroyed)", orphaned_appeals_sql)
      end
    end

    def self.step(label, sql)
      count = ApplicationRecord.transaction { ApplicationRecord.connection.execute(sql).cmd_tuples }
      puts "#{label}: #{count}"
    end

    # Only the newest unresolved flag of a still-deleted post becomes active, and only if
    # the post has no active row yet (it may have been deleted again by the new code).
    def self.copy_sql
      <<~SQL.squish
        INSERT INTO post_deletions (post_id, deleter_id, creator_ip_addr, reason, is_undeleted, source_post_flag_id, created_at)
        SELECT f.post_id, f.creator_id, f.creator_ip_addr,
               COALESCE(NULLIF(TRIM(f.reason), ''), 'Unknown'),
               NOT (COALESCE(f.is_newest_active, false) AND p.is_deleted
                    AND NOT EXISTS (SELECT 1 FROM post_deletions a WHERE a.post_id = f.post_id AND NOT a.is_undeleted)),
               f.id, f.created_at
        FROM (
          SELECT *, id = max(id) FILTER (WHERE NOT is_resolved) OVER (PARTITION BY post_id) AS is_newest_active
          FROM post_flags WHERE is_deletion
        ) f
        JOIN posts p ON p.id = f.post_id
        WHERE NOT EXISTS (SELECT 1 FROM post_deletions pd WHERE pd.source_post_flag_id = f.id)
      SQL
    end

    # Rows copied while active whose post has since been undeleted by the old code.
    def self.reconcile_sql
      <<~SQL.squish
        UPDATE post_deletions pd
        SET is_undeleted = true
        FROM post_flags f, posts p
        WHERE f.id = pd.source_post_flag_id AND p.id = pd.post_id
          AND NOT pd.is_undeleted
          AND (f.is_resolved OR NOT p.is_deleted)
      SQL
    end

    # Attributes each undeletion to the first undelete event before the post's next deletion.
    def self.undeleter_sql
      <<~SQL.squish
        UPDATE post_deletions pd
        SET undeleter_id = m.creator_id, undeleted_at = m.created_at
        FROM (
          SELECT DISTINCT ON (b.id) b.id, e.creator_id, e.created_at
          FROM (
            SELECT id, post_id, created_at, is_undeleted, undeleter_id,
                   lead(created_at) OVER (PARTITION BY post_id ORDER BY created_at, id) AS next_created_at
            FROM post_deletions
          ) b
          JOIN post_events e ON e.post_id = b.post_id AND e.action = #{UNDELETED_EVENT}
            AND e.created_at >= b.created_at
            AND e.created_at < COALESCE(b.next_created_at, 'infinity')
          WHERE b.is_undeleted AND b.undeleter_id IS NULL
          ORDER BY b.id, e.created_at, e.id
        ) m
        WHERE m.id = pd.id
      SQL
    end

    def self.appeals_sql
      <<~SQL.squish
        UPDATE appeals SET qtype = 'post_deletion', disp_id = pd.id
        FROM post_deletions pd
        WHERE appeals.qtype = 'flag' AND pd.source_post_flag_id = appeals.disp_id
      SQL
    end

    # Whatever the remap left behind has no post anymore. A negated id keeps the old flag id
    # without matching a real row.
    def self.orphaned_appeals_sql
      <<~SQL.squish
        UPDATE appeals SET qtype = 'post_deletion', disp_id = -disp_id
        WHERE qtype = 'flag'
      SQL
    end
  end
end

Fixes::BackfillPostDeletions.run unless Rails.env.test?
