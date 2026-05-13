# frozen_string_literal: true

module Sources
  module Alternates
    class Webtoons < Base
      def force_https?
        true
      end

      def domains
        ["webtoons.com"]
      end

      def original_url
        # Convert mobile URLs to base ones
        if @parsed_url.host == "m.webtoons.com"
          @parsed_url.host = "www.webtoons.com"
        end
        @url = @parsed_url.to_s
      end
    end
  end
end
