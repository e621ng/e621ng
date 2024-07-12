# frozen_string_literal: true

module Sources
  module Alternates
    class Furaffinity < Base
      IMAGE_TO_ARTIST = /facdn\.net\/art\/([0-9a-zA-Z_.~\-]+)/
      SUBMISSION_URL = /furaffinity\.net\/view\/(\d+)/

      def force_https?
        true
      end

      def domains
        ["furaffinity.net", "facdn.net"]
      end

      def parse
        if @url =~ IMAGE_TO_ARTIST
          @gallery_url = "https://www.furaffinity.net/user/#{$1}/"
          @direct_url = @url
        end
      end
    end
  end
end
