# frozen_string_literal: true

# Backfills the is_animated flag on posts based on their actual file, and
# re-derives the animated_gif / animated_png / animated_webp tags for any post
# whose tags no longer match the file (e.g. the tag was removed by a user).
module Fixes
  class BackfillIsAnimated
    ANIMATED_TAGS = %w[animated_gif animated_png animated_webp].freeze

    def self.run
      Post.without_timeout do # rubocop:disable Metrics/BlockLength
        posts = Post.where(file_ext: %w[gif png webp webm mp4])
        total = posts.size
        puts "Found #{total} candidate posts"
        return if total == 0

        processed = 0
        updated = 0
        posts.find_each do |post|
          begin
            file_path = post.file_path
            animated = file_path.present? && File.exist?(file_path) && post.is_animated_file?(file_path)

            flag_changed = post.is_animated? != animated
            tags_changed = expected_tags(post, animated) != current_tags(post)

            if flag_changed || tags_changed
              post.is_animated = animated
              # Force tag normalization so add_automatic_tags re-derives the
              # animated_* tags from the freshly-set flag. Only done when the
              # tags are actually wrong, to bound the work and avoid needless
              # reindexing.
              post.tag_string_will_change! if tags_changed
              post.do_not_version_changes = true
              post.save!
              updated += 1
            end
          rescue StandardError => e
            puts "Error processing post #{post.id}: #{e.message}"
          end

          processed += 1
          print "\rProcessed #{processed}/#{total} posts" if processed % 10 == 0
        end

        puts "\nDone! Updated #{updated}/#{total} posts"
      end
    end

    # The animated_* tag(s) the post should have, given its file type and
    # whether the file is animated. Videos get none (the generic `animated`
    # tag is managed separately and is not touched here).
    def self.expected_tags(post, animated)
      return [] unless animated
      return ["animated_gif"] if post.is_gif?
      return ["animated_png"] if post.is_png?
      return ["animated_webp"] if post.is_webp?
      []
    end

    def self.current_tags(post)
      ANIMATED_TAGS.select { |tag| post.has_tag?(tag) }
    end

    private_class_method :expected_tags, :current_tags
  end
end

Fixes::BackfillIsAnimated.run
