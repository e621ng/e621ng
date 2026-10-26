# frozen_string_literal: true

module Fixes
  class BackfillHasSoundTag
    def self.run
      Post.without_timeout do
        posts = Post.where(file_ext: FileMethods::VIDEO_FILE_TYPES)
        puts "Updating has_sound for #{posts.size} video posts."

        skipped = 0
        errors = 0

        posts.find_each do |post|
          if post.respond_to?(:has_sound)
            skipped += 1
            next
          end

          post.has_sound = post.video_has_sound?(post.file_path)

          if post.has_sound && !post.has_tag?("sound")
            post.add_tag("sound")
          elsif !post.has_sound && post.has_tag?("sound")
            post.remove_tag("sound")
          end

          post.do_not_version_changes = true
          post.save!
        rescue StandardError => e
          puts "Error processing post #{post.id}: #{e.message}"
          errors += 1
        end

        puts "Done. Skipped: #{skipped}, Errors: #{errors}, Updated: #{posts.size - skipped - errors}"
      end
    end
  end
end

Fixes::BackfillHasSoundTag.run
