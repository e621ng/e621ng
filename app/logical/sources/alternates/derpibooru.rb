# frozen_string_literal: true

module Sources
  module Alternates
    class Derpibooru < Base
      def force_https?
        true
      end

      def domains
        ["derpibooru.org", "derpicdn.net"]
      end

      def original_url
        # Remove query parameters from derpibooru.org image URLs
        if @parsed_url.host == "derpibooru.org" && @parsed_url.path.start_with?("/images/")
          @parsed_url.query = nil
        end

        # Clean up derpicdn.net image URLs by standardizing path and filename
        if @parsed_url.host == "derpicdn.net" && @parsed_url.path.include?("/img/")
          path_parts = @parsed_url.path.split("/")

          # Use view path instead of download
          if path_parts.include?("download")
            download_index = path_parts.index("download")
            path_parts[download_index] = "view"
          end

          # Strip tag information from filename
          if path_parts.last&.include?("__")
            filename = path_parts.last
            # Extract ID (before first __)
            if (match = filename.match(/^(\d+)__/))
              image_id = match[1]
              # Extract extension
              extension = File.extname(filename)
              # Replace filename with just ID and extension
              path_parts[-1] = "#{image_id}#{extension}"
            end
          end

          @parsed_url.path = path_parts.join("/")
        end

        @url = @parsed_url.to_s
      end
    end
  end
end
