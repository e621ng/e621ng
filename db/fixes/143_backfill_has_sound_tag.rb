# frozen_string_literal: true

module Fixes
  class BackfillHasSoundTag
    def self.run
      Post.without_timeout do
        posts = Post.where(file_ext: FileMethods::VIDEO_FILE_TYPES)
        puts "Updating has_sound for #{posts.size} video posts."

        errors = 0
        changes = 0

        posts.find_each do |post|
          post.has_sound = post.video_has_sound?(post.file_path)

          if post.has_sound && !post.has_tag?("sound")
            post.add_tag("sound")
          elsif !post.has_sound && post.has_tag?("sound")
            post.remove_tag("sound")
          end

          # covers both the flag (bit_flags) and the tag (tag_string)
          next unless post.changed?

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

Fixes::BackfillHasSoundTag.run unless Rails.env.test?
