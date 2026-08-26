# frozen_string_literal: true

# One-shot backfill for the upload karma ledger (design doc 32).
#
# Derives every uploader's karma from current post state, inserts it as
# historically-dated upload_karma_events rows in chronological order (so ids
# ascend with created_at), then overwrites every balance with its ledger sum.
# Previous staff overrides are deliberately discarded.
#
# Must run under the site write freeze, before any live ledger row exists —
# it refuses to run otherwise.
module Fixes
  class RecalculateUploadKarmaLedger
    def self.run
      raise "upload_karma_events is not empty; this backfill must run exactly once, before any live rows" if UploadKarmaEvent.exists?

      conn = ApplicationRecord.connection
      ApplicationRecord.without_timeout do
        inserted = conn.execute(insert_sql).cmd_tuples
        puts "Inserted #{inserted} ledger rows" unless Rails.env.test?

        conn.execute(<<~SQL.squish)
          UPDATE user_statuses us
          SET upload_karma = sums.total
          FROM (SELECT user_id, SUM(delta) AS total FROM upload_karma_events GROUP BY user_id) sums
          WHERE sums.user_id = us.user_id AND us.upload_karma IS DISTINCT FROM sums.total
        SQL
        conn.execute(<<~SQL.squish)
          UPDATE user_statuses us
          SET upload_karma = 0
          WHERE us.upload_karma <> 0
            AND NOT EXISTS (SELECT 1 FROM upload_karma_events e WHERE e.user_id = us.user_id)
        SQL

        drift = conn.select_value(<<~SQL.squish).to_i
          SELECT COUNT(*) FROM user_statuses us
          LEFT JOIN (SELECT user_id, SUM(delta) AS total FROM upload_karma_events GROUP BY user_id) e
            ON e.user_id = us.user_id
          WHERE us.upload_karma IS DISTINCT FROM COALESCE(e.total, 0)
        SQL
        raise "karma/ledger drift for #{drift} users after recalculation" if drift > 0

        users = conn.select_value("SELECT COUNT(DISTINCT user_id) FROM upload_karma_events")
        puts "Done. Ledger covers #{users} users; all balances match their sums" unless Rails.env.test?
      end
    end

    # One row per post (live => credit, deleted non-takedown => penalty) plus one
    # per outstanding replacement penalty. The window ORDER BY matches the outer
    # ORDER BY so per-user running balances agree with the global insert order.
    def self.insert_sql
      reasons = UploadKarmaEvent.reasons
      actions = PostEvent.actions

      <<~SQL.squish
        WITH latest_approval AS (
          SELECT DISTINCT ON (post_id) post_id, user_id, created_at
          FROM post_approvals
          ORDER BY post_id, id DESC
        ), latest_approval_event AS (
          SELECT DISTINCT ON (post_id) post_id, creator_id, created_at
          FROM post_events
          WHERE action = #{actions[:approved]}
          ORDER BY post_id, id DESC
        ), latest_deletion_event AS (
          SELECT DISTINCT ON (post_id) post_id, creator_id, created_at
          FROM post_events
          WHERE action = #{actions[:deleted]}
          ORDER BY post_id, id DESC
        ), deletion_flag AS (
          SELECT DISTINCT ON (post_id) post_id, creator_id, created_at,
                 (reason LIKE 'takedown #%') AS is_takedown
          FROM post_flags
          WHERE is_deletion AND NOT is_resolved
          ORDER BY post_id, id DESC
        ), events AS (
          SELECT p.uploader_id AS user_id,
                 COALESCE(p.approver_id, la.user_id, lae.creator_id, p.uploader_id) AS creator_id,
                 p.id AS post_id,
                 CASE WHEN p.approver_id IS NOT NULL OR la.post_id IS NOT NULL
                      THEN #{reasons[:approved]} ELSE #{reasons[:queue_bypass]} END AS reason,
                 #{UserStatus::KARMA_APPROVED_CREDIT} AS delta,
                 COALESCE(la.created_at, lae.created_at, p.created_at) AS event_time
          FROM posts p
          LEFT JOIN latest_approval la ON la.post_id = p.id
          LEFT JOIN latest_approval_event lae ON lae.post_id = p.id
          WHERE NOT p.is_deleted AND NOT p.is_pending

          UNION ALL

          SELECT p.uploader_id,
                 COALESCE(lde.creator_id, df.creator_id, p.uploader_id),
                 p.id,
                 #{reasons[:deleted]},
                 #{-UserStatus::KARMA_DELETION_PENALTY},
                 COALESCE(lde.created_at, df.created_at, p.updated_at, p.created_at)
          FROM posts p
          LEFT JOIN latest_deletion_event lde ON lde.post_id = p.id
          LEFT JOIN deletion_flag df ON df.post_id = p.id
          WHERE p.is_deleted AND NOT COALESCE(df.is_takedown, FALSE)

          UNION ALL

          SELECT r.uploader_id_on_approve,
                 COALESCE(r.approver_id, r.creator_id),
                 r.post_id,
                 #{reasons[:replacement_penalty]},
                 #{-UserStatus::KARMA_REPLACEMENT_PENALTY},
                 r.updated_at
          FROM post_replacements2 r
          WHERE r.penalize_uploader_on_approve
            AND r.uploader_id_on_approve IS NOT NULL
            AND r.status IN ('approved', 'original')
        )
        INSERT INTO upload_karma_events (user_id, creator_id, post_id, reason, delta, balance, extra_data, created_at)
        SELECT user_id, creator_id, post_id, reason, delta,
               SUM(delta) OVER (PARTITION BY user_id ORDER BY event_time, post_id, reason ROWS UNBOUNDED PRECEDING),
               '{"backfill": true}'::jsonb,
               event_time
        FROM events
        ORDER BY event_time, post_id, reason
      SQL
    end
  end
end

Fixes::RecalculateUploadKarmaLedger.run unless Rails.env.test?
