# frozen_string_literal: true

# Backfills `posts.hotness` for posts that still have the default value (0), then
# mirrors it into OpenSearch with a lightweight partial-document bulk update
# (only the `hotness` field — NOT a full `import`, which would needlessly
# re-denormalize every document). Run after 136_1 adds the index mapping.
#
# Resumable: only posts whose hotness is still 0 are touched, so the script can be
# stopped and restarted without redoing finished work. A real hotness value is
# never 0 (the created_at term alone is ~3,900), so 0 reliably means "not done".
# To force a full recompute (e.g. after changing Post::HOTNESS_TIME_DIVISOR),
# reset first and re-run:
#   Post.without_timeout { Post.in_batches.update_all(hotness: 0) }
#
module Fixes
  class BackfillHotness
    BATCH_SIZE = 1_000

    def self.run
      client = Post.document_store.client
      index = Post.document_store.index_name
      done = 0

      Post.without_timeout do
        Post.where(hotness: 0).find_in_batches(batch_size: BATCH_SIZE) do |batch|
          values = batch.to_h { |post| [post.id, post.compute_hotness] }

          # Mirror into OpenSearch first (idempotent partial update). Persisting
          # the column last means a crash can never mark a post done while the
          # index still lags.
          response = client.bulk(body: values.map do |id, hotness|
            { update: { _index: index, _id: id, data: { doc: { hotness: hotness } } } }
          end)

          # Skip persisting any post whose index update failed, so it stays at
          # hotness 0 and gets retried on a later run instead of being marked done
          # with a stale index.
          failed = Set.new
          if response["errors"]
            response["items"].each { |item| failed << item["update"]["_id"].to_i if item["update"]["error"] }
            puts "  opensearch errors for #{failed.size} posts in batch through ##{batch.last.id}; left for a re-run"
          end

          # Persist the column in a single UPDATE per batch (one statement instead
          # of one per post). On restart these rows (hotness != 0) are skipped.
          persist = values.except(*failed)
          unless persist.empty?
            cases = persist.map { |id, hotness| "WHEN #{id.to_i} THEN #{Post.connection.quote(hotness)}" }.join(" ")
            Post.where(id: persist.keys).update_all("hotness = CASE id #{cases} END")
          end

          done += batch.size
          puts "backfilled #{done} (through post ##{batch.last.id})"
        end
      end

      puts "Done!"
    end
  end
end

Fixes::BackfillHotness.run
