# frozen_string_literal: true

module Sources
  module Alternates
    class Youtube < Base
      def force_https?
        true
      end

      def domains
        ["youtube.com", "youtu.be"]
      end

      def original_url
        # Transform youtu.be short URLs to full youtube.com watch URLs
        if @parsed_url.host == "youtu.be"
          video_id = @parsed_url.path.delete_prefix("/") # Remove leading slash
          @parsed_url.host = "www.youtube.com"
          @parsed_url.path = "/watch"
          @parsed_url.query_values = { "v" => video_id }
        end

        # Transform YouTube Shorts URLs to regular watch URLs
        if @parsed_url.host&.include?("youtube.com") && @parsed_url.path.start_with?("/shorts/")
          video_id = @parsed_url.path.split("/").last # Extract video ID from /shorts/VIDEO_ID
          @parsed_url.path = "/watch"
          @parsed_url.query_values = { "v" => video_id }
        end

        # Normalize host to canonical www.youtube.com
        if @parsed_url.host&.include?("youtube.com")
          @parsed_url.host = "www.youtube.com"
        end

        # Remove tracking and unnecessary query parameters
        if @parsed_url.query_values.present?
          query_values = @parsed_url.query_values

          if @parsed_url.path == "/watch" && query_values["v"].present?
            @parsed_url.query_values = { "v" => query_values["v"] }
          else
            query_values.delete_if { |key, _| key.start_with?("utm_") }
            query_values.delete("si") # YouTube sharing tracking parameter
            query_values.delete("list") # Remove playlist parameter
            query_values.delete("index") # Remove playlist index parameter
            query_values.delete("t") # Remove timestamp parameter
            query_values.delete("feature") # Remove feature parameter

            @parsed_url.query_values = query_values.empty? ? nil : query_values
          end
        end

        @url = @parsed_url.to_s
      end
    end
  end
end
