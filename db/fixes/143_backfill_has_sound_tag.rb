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
          changed = false

          if post.has_sound && !post.has_tag?("sound")
            post.add_tag("sound")
            changed = true
          elsif !post.has_sound && post.has_tag?("sound")
            post.remove_tag("sound")
            changed = true
          end

          next unless changed

          post.do_not_version_changes = true
          post.save!
          changed += 1
        rescue StandardError => e
          puts "Error processing post #{post.id}: #{e.message}"
          errors += 1
        end

        puts "Done. Errors: #{errors}, Updated: #{changes}".
      end
    end
  end
end

Fixes::BackfillHasSoundTag.run
