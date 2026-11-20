# frozen_string_literal: true

# Backfills the duration of animated PNG and WebP posts, and the playtime tags derived from it.
module Fixes
  class BackfillAnimatedImageDuration
    def self.run
      Post.without_timeout do # rubocop:disable Metrics/BlockLength
        posts = Post.where(file_ext: %w[png webp], duration: nil)
                    .where("bit_flags & ? > 0", Post.flag_value_for("is_animated"))
        puts "Updating duration for #{posts.size} animated PNG/WebP posts."

        errors = 0
        changes = 0

        posts.find_each do |post|
          file_path = post.file_path
          unless File.exist?(file_path)
            puts "File not found for post #{post.id}: #{file_path}"
            next
          end

          duration = post.video_duration(file_path, animated: true)
          if duration.blank?
            puts "Could not determine duration for post #{post.id}"
            next
          end

          post.duration = duration
          # Re-derives long_playtime / short_playtime.
          post.tag_string_will_change!
          post.do_not_version_changes = true
          post.save!
          changes += 1
        rescue StandardError => e
          puts "Error processing post #{post.id}: #{e.message}"
          errors += 1
        end

        puts "Done. Errors: #{errors}, Updated: #{changes}."
      end
    end
  end
end

Fixes::BackfillAnimatedImageDuration.run unless Rails.env.test?
