# frozen_string_literal: true

module Fixes
  class BackfillHotness
    def self.run
      Post.without_timeout do
        total = Post.count
        puts "Backfilling hotness for #{total} posts"
        Post.find_each.with_index do |post, i|
          post.update_column(:hotness, post.compute_hotness)
          puts "#{i}/#{total}" if (i % 10_000) == 0
        end
      end

      puts "Reindexing..."
      Post.document_store.import
      puts "Done!"
    end
  end
end

Fixes::BackfillHotness.run
