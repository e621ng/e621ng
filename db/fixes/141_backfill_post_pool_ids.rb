# frozen_string_literal: true

# Backfills posts.pool_ids from pools.post_ids (the definitive source of truth).
#
# Default mode only processes rows where pool_ids IS NULL — new rows default to
# '{}', so NULL marks "not yet backfilled" and the run is resumable.
# FULL=1 recomputes every post instead, skipping rows that already match. Run
# that after a rollback window, during which old code updated pool membership
# in pool_string without maintaining pool_ids.
module Fixes
  class BackfillPostPoolIds
    BATCH_SIZE = 10_000

    # Membership order is not semantic; ordering by pool id keeps reruns deterministic.
    POOL_IDS_SQL = <<~SQL.squish
      (SELECT COALESCE(array_agg(pools.id ORDER BY pools.id), '{}')
       FROM pools WHERE pools.post_ids @> ('{}'::int[] || posts.id))
    SQL

    def self.run(full: ENV["FULL"].present?)
      processed = 0
      updated = 0

      Post.without_timeout do
        scope = full ? Post.all : Post.where(pool_ids: nil)
        scope.in_batches(of: BATCH_SIZE) do |batch|
          batch = batch.where("pool_ids IS DISTINCT FROM #{POOL_IDS_SQL}") if full
          updated += batch.update_all("pool_ids = #{POOL_IDS_SQL}")
          processed += BATCH_SIZE
          sleep(0.1) # bound replica lag / let autovacuum breathe

          puts "Processed ~#{processed} posts, updated #{updated}" unless Rails.env.test?
        end
      end

      puts "Done. Updated #{updated} posts#{' (full recompute)' if full}" unless Rails.env.test?
    end
  end
end

Fixes::BackfillPostPoolIds.run unless Rails.env.test?
