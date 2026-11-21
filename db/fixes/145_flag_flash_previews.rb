# frozen_string_literal: true

# Flash previews cannot be generated, so they are supplied externally.
# Sets has_flash_preview on each flash post whose preview files are present, and clears it otherwise.
# Safe to re-run after adding more previews.
module Fixes
  class FlagFlashPreviews
    def self.run
      sm = Danbooru.config.storage_manager

      Post.without_timeout do
        posts = Post.where(file_ext: "swf")
        puts "Checking previews for #{posts.size} flash posts."

        flagged = 0
        cleared = 0

        posts.find_each do |post|
          present = %i[preview_jpg preview_webp].all? do |type|
            File.exist?(sm.file_path(post.md5, post.file_ext, type, protect: post.protect_file?))
          end
          next if post.has_flash_preview? == present

          post.has_flash_preview = present
          post.update_columns(bit_flags: post.bit_flags)

          if present
            post.update_iqdb_async
            flagged += 1
          else
            cleared += 1
          end
        end

        puts "Done. Flagged: #{flagged}, Cleared: #{cleared}."
      end
    end
  end
end

Fixes::FlagFlashPreviews.run unless Rails.env.test?
