# frozen_string_literal: true

module Fixes
  class BackfillHasSoundTag
    def self.run
      Post.in_batches(load: true, order: :desc).each_with_index do |group, index|
        group.each do |post|
          post.has_sound = post.video_has_sound?(post.file_path)

          if post.has_sound && !post.has_tag?("sound") then
            post.add_tag("sound")
          elsif post.has_tag("sound") then
            post.remove_tag("sound")
          end
        end
      end
    end
  end
end

Fixes::BackfillHasSoundTag.run
