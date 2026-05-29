# frozen_string_literal: true

module Sources
  module Alternates
    class Tapas < Base
      def force_https?
        true
      end

      def domains
        ["tapas.io"]
      end

      def original_url
        # Convert mobile URLs to base ones
        if @parsed_url.host == "m.tapas.io"
          @parsed_url.host = "tapas.io"
        end
        @url = @parsed_url.to_s
      end
    end
  end
end
