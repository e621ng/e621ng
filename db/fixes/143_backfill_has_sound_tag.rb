# frozen_string_literal: true

module Fixes
  class BackfillHasSoundTag
    def self.run
      Post.without_timeout do
        posts = Post.where(file_ext: FileMethods::VIDEO_FILE_TYPES)
        puts "Updating has_sound for #{posts.size} video posts."

        posts.find_each do |post|
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
        end

        puts "Done."
      end
    end
  end
end

Fixes::BackfillHasSoundTag.run
