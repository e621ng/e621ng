# frozen_string_literal: true

# Backfills the duration field for GIF files based on their actual content
module Fixes
  class BackfillGifDuration
    def self.run
      Post.without_timeout do # rubocop:disable Metrics/BlockLength
        posts = Post.where(file_ext: "gif", duration: nil)
        total = posts.size
        puts "Found #{total} GIFs to process"
        return if total == 0

        processed = 0
        updated = 0
        posts.find_each do |post|
          begin
            file_path = post.file_path
            if File.exist?(file_path)
              if post.is_animated_gif?(file_path)
                duration = calculate_gif_duration(file_path)
                if duration.present?
                  post.duration = duration
                  post.tag_string_will_change!
                  post.do_not_version_changes = true
                  post.save!
                  updated += 1
                else
                  puts "Could not determine duration for post #{post.id}: #{file_path}"
                end
              end
            else
              puts "File not found for post #{post.id}: #{file_path}"
            end
          rescue StandardError => e
            puts "Error processing post #{post.id}: #{e.message}"
          end

          processed += 1
          print "\rProcessed #{processed}/#{total} posts" if processed % 10 == 0
        end

        puts "\nDone! Updated duration for #{updated}/#{total} posts (#{total - updated} were static GIFs or missing)"
      end
    end

    def self.calculate_gif_duration(file_path)
      video = FFMPEG::Movie.new(file_path)
      duration = video.duration
      return nil unless duration && duration > 0
      duration
    end

    private_class_method :calculate_gif_duration
  end
end

Fixes::BackfillGifDuration.run
