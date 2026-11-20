# frozen_string_literal: true

module Fixes
  class BackfillAspectRatioPrecision
    BATCH_SIZE = 1_000

    def self.run
      client = Post.document_store.client
      index = Post.document_store.index_name
      done = 0

      Post.without_timeout do
        Post.select(:id, :image_width, :image_height).find_in_batches(batch_size: BATCH_SIZE) do |batch|
          response = client.bulk(body: batch.map do |post|
            { update: { _index: index, _id: post.id, data: { doc: { aspect_ratio: (post.image_width.to_f / [post.image_height, 1].max).round(7) } } } }
          end)

          if response["errors"]
            failed = response["items"].select { |item| item["update"]["error"] }.map { |item| item["update"]["_id"] }
            puts "  opensearch errors for #{failed.size} posts in batch through ##{batch.last.id}: #{failed.first(10).join(', ')}"
          end

          done += batch.size
          puts "backfilled #{done} (through post ##{batch.last.id})"
        end
      end

      puts "Done!"
    end
  end
end

Fixes::BackfillAspectRatioPrecision.run
