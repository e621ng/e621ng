# frozen_string_literal: true

# Backfills NULLs in columns that db/structure.sql declares NOT NULL but prod relaxed to fit
# pre-rewrite data. All NULLs predate 2020-03-05 (the e621ng launch); nothing writes new ones.
#
# Fill values, per column:
# - forum_posts.updater_id / news_updates.updater_id <- creator_id: the old code only
#   set updater on edit, so NULL means "never edited".
# - post_versions.updater_id <- 0, tickets.handler_id <- 0: those columns already use
#   0 as their sentinel (DEFAULT 0). post_versions is updated with raw SQL, so the
#   OpenSearch index is not touched; stale docs are harmless because NULL and 0 both
#   resolve to "no user" in updater: searches.
# - notes.creator_id, note_versions.updater_id, wiki_page_versions.updater_id
#   <- User.system: 42/210/81 rows from 2007-2016 with no recoverable author.
# - user_statuses.created_at/updated_at <- users.created_at: launch-day backfill
#   created ~448k status rows without timestamps.
#
# Idempotent: every UPDATE is scoped to IS NULL.
module Fixes
  class BackfillLegacyNullColumns
    BATCH_SIZE = 10_000

    def self.run
      conn = ApplicationRecord.connection
      system_user_id = User.system.id

      ApplicationRecord.without_timeout do
        batched_update(conn, "forum_posts", "updater_id IS NULL", "updater_id = creator_id")
        batched_update(conn, "post_versions", "updater_id IS NULL", "updater_id = 0")

        puts "news_updates.updater_id: #{conn.execute(<<~SQL.squish).cmd_tuples} rows"
          UPDATE news_updates SET updater_id = creator_id WHERE updater_id IS NULL
        SQL
        puts "tickets.handler_id: #{conn.execute(<<~SQL.squish).cmd_tuples} rows"
          UPDATE tickets SET handler_id = 0 WHERE handler_id IS NULL
        SQL
        puts "notes.creator_id: #{conn.execute(<<~SQL.squish).cmd_tuples} rows"
          UPDATE notes SET creator_id = #{system_user_id} WHERE creator_id IS NULL
        SQL
        puts "note_versions.updater_id: #{conn.execute(<<~SQL.squish).cmd_tuples} rows"
          UPDATE note_versions SET updater_id = #{system_user_id} WHERE updater_id IS NULL
        SQL
        puts "wiki_page_versions.updater_id: #{conn.execute(<<~SQL.squish).cmd_tuples} rows"
          UPDATE wiki_page_versions SET updater_id = #{system_user_id} WHERE updater_id IS NULL
        SQL

        # user_name_change_requests.user_id (1 NULL row from 2014) was fixed manually
        # in prod on 2026-08-12.

        # Two passes: rows missing created_at (fill both from the user's registration
        # date), then any stragglers missing only updated_at.
        batched_update(conn, "user_statuses", "user_statuses.created_at IS NULL",
                       "created_at = u.created_at, updated_at = COALESCE(user_statuses.updated_at, u.created_at)",
                       from: "users u", join: "u.id = user_statuses.user_id")
        puts "user_statuses.updated_at stragglers: #{conn.execute(<<~SQL.squish).cmd_tuples} rows"
          UPDATE user_statuses SET updated_at = created_at WHERE updated_at IS NULL
        SQL
      end
    end

    def self.batched_update(conn, table, predicate, assignment, from: nil, join: nil) # rubocop:disable Metrics/ParameterLists
      total = 0
      loop do
        sql = <<~SQL.squish
          UPDATE #{table} SET #{assignment}
          #{"FROM #{from}" if from}
          WHERE #{table}.id IN (
            SELECT id FROM #{table} WHERE #{predicate} LIMIT #{BATCH_SIZE}
          )
          #{"AND #{join}" if join}
          AND #{predicate}
        SQL
        updated = conn.execute(sql).cmd_tuples
        total += updated
        break if updated == 0

        puts "#{table}: #{total} rows" unless Rails.env.test?
        sleep(0.1) # bound replica lag / let autovacuum breathe
      end
      puts "#{table} (#{assignment.split(',').first.strip}): #{total} rows total"
    end
  end
end

Fixes::BackfillLegacyNullColumns.run unless Rails.env.test?
