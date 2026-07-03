# frozen_string_literal: true

module Sources
  module Alternates
    class Facebook < Base
      def force_https?
        true
      end

      def domains
        ["facebook.com"]
      end

      def original_url
        # Convert mobile/alternate subdomain URLs to www
        if %w[m.facebook.com web.facebook.com].include?(@parsed_url.host)
          @parsed_url.host = "www.facebook.com"
        end
        # Normalize /photo and /photo/ to /photo.php
        if @parsed_url.path.match?(%r{\A/photo/?\z})
          @parsed_url.path = "/photo.php"
        end
        # Keep only fbid param for photo.php URLs
        if @parsed_url.path == "/photo.php" && @parsed_url.query_values&.key?("fbid")
          @parsed_url.query_values = { "fbid" => @parsed_url.query_values["fbid"] }
        end
        # Keep only story_fbid and id params for story.php URLs
        if @parsed_url.path == "/story.php" && @parsed_url.query_values&.key?("story_fbid")
          @parsed_url.query_values = @parsed_url.query_values.slice("story_fbid", "id")
        end
        @url = @parsed_url.to_s
      end
    end
  end
end
