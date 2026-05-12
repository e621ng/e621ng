# frozen_string_literal: true

module Sources
  module Alternates
    class Imgur < Base
      def force_https?
        true
      end

      def domains
        ["imgur.com"]
      end

      def original_url
        # Convert mobile URLs to base ones
        if @parsed_url.host == "m.imgur.com"
          @parsed_url.host = "imgur.com"
        end
        @url = @parsed_url.to_s
      end
    end
  end
end
