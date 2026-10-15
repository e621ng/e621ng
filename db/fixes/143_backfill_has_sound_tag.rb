# frozen_string_literal: true

module Fixes
  class BackfillHasSoundTag
    def self.run
      posts = Post.where(file_ext: FileMethods::VIDEO_FILE_TYPES)
      puts "Updating has_sound for #{posts.size} video posts."

      posts.find_each do |post|
        post.has_sound = post.video_has_sound?(post.file_path)

        if post.has_sound && !post.has_tag?("sound")
          post.add_tag("sound")
        elsif post.has_tag?("sound")
          post.remove_tag("sound")
        end

        post.save!
      end

      puts "Done."
    end
  end
end

Fixes::BackfillHasSoundTag.run
