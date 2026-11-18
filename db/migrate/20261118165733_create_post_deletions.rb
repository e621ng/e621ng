# frozen_string_literal: true

class CreatePostDeletions < ActiveRecord::Migration[8.1]
  UNDELETED_EVENT = 1

  def up
    ApplicationRecord.without_timeout do # rubocop:disable Metrics/BlockLength
      create_table :post_deletions do |t|
        t.integer :post_id, null: false
        t.integer :deleter_id, null: false
        t.integer :undeleter_id
        t.inet :creator_ip_addr, null: false
        t.text :reason, null: false
        t.boolean :is_undeleted, null: false, default: false
        t.integer :source_post_flag_id, null: false
        t.datetime :created_at, null: false
        t.datetime :undeleted_at
      end

      execute(<<~SQL.squish)
        INSERT INTO post_deletions (post_id, deleter_id, creator_ip_addr, reason, is_undeleted, source_post_flag_id, created_at)
        SELECT f.post_id, f.creator_id, f.creator_ip_addr,
               COALESCE(NULLIF(TRIM(f.reason), ''), 'Unknown'),
               NOT (COALESCE(f.is_newest_active, false) AND p.is_deleted),
               f.id, f.created_at
        FROM (
          SELECT *, id = max(id) FILTER (WHERE NOT is_resolved) OVER (PARTITION BY post_id) AS is_newest_active
          FROM post_flags WHERE is_deletion
        ) f
        JOIN posts p ON p.id = f.post_id
      SQL

      add_index :post_deletions, :post_id, unique: true, where: "is_undeleted = false", name: "index_post_deletions_active_unique"
      add_index :post_deletions, %i[post_id id]
      add_index :post_deletions, :deleter_id
      add_index :post_deletions, :creator_ip_addr
      add_index :post_deletions, :source_post_flag_id, unique: true
      add_index :post_deletions, :created_at, where: "is_undeleted = false", name: "index_post_deletions_active_created_at"
      add_index :post_deletions, "to_tsvector('english'::regconfig, reason)", using: :gin, name: "index_post_deletions_on_reason_tsvector"

      add_foreign_key :post_deletions, :posts, column: :post_id, on_delete: :cascade
      add_foreign_key :post_deletions, :users, column: :deleter_id
      add_foreign_key :post_deletions, :users, column: :undeleter_id

      assert_zero!("deletion flags without a post_deletions row",
                   "SELECT (SELECT count(*) FROM post_flags WHERE is_deletion) - (SELECT count(*) FROM post_deletions)")

      execute(<<~SQL.squish)
        UPDATE post_deletions pd
        SET undeleter_id = m.creator_id, undeleted_at = m.created_at
        FROM (
          SELECT DISTINCT ON (b.id) b.id, e.creator_id, e.created_at
          FROM (
            SELECT id, post_id, created_at, is_undeleted,
                   lead(created_at) OVER (PARTITION BY post_id ORDER BY created_at, id) AS next_created_at
            FROM post_deletions
          ) b
          JOIN post_events e ON e.post_id = b.post_id AND e.action = #{UNDELETED_EVENT}
            AND e.created_at >= b.created_at
            AND e.created_at < COALESCE(b.next_created_at, 'infinity')
          WHERE b.is_undeleted
          ORDER BY b.id, e.created_at, e.id
        ) m
        WHERE m.id = pd.id
      SQL

      execute(<<~SQL.squish)
        UPDATE appeals SET qtype = 'post_deletion', disp_id = pd.id
        FROM post_deletions pd
        WHERE appeals.qtype = 'flag' AND pd.source_post_flag_id = appeals.disp_id
      SQL

      assert_zero!("appeals still anchored to a post flag",
                   "SELECT count(*) FROM appeals WHERE qtype = 'flag'")

      assert_zero!("user_statuses whose post_flag_count is below their deletion count",
                   <<~SQL.squish)
                     SELECT count(*) FROM user_statuses us
                     JOIN (SELECT creator_id, count(*) AS deletions FROM post_flags WHERE is_deletion GROUP BY creator_id) d
                       ON d.creator_id = us.user_id
                     WHERE us.post_flag_count < d.deletions
                   SQL
      execute(<<~SQL.squish)
        UPDATE user_statuses us
        SET post_flag_count = us.post_flag_count - d.deletions
        FROM (SELECT creator_id, count(*) AS deletions FROM post_flags WHERE is_deletion GROUP BY creator_id) d
        WHERE us.user_id = d.creator_id
      SQL

      execute("DELETE FROM post_flags WHERE is_deletion")

      remove_column :post_flags, :is_deletion
      remove_column :post_deletions, :source_post_flag_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def assert_zero!(what, sql)
    count = select_value(sql).to_i
    return if count == 0

    message = "CreatePostDeletions: #{count} #{what}"
    say(message) # without_timeout eats the exception message
    raise message
  end
end
