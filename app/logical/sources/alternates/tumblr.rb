# frozen_string_literal: true

module Sources
  module Alternates
    class Tumblr < Base
      def force_https?
        true
      end

      def domains
        ["tumblr.com"]
      end

      def original_url
        # Eagerly remove the unnecessary source parameter
        unless @parsed_url.query_values.nil?
          query_values = @parsed_url.query_values
          query_values.delete("source")
          # redirect_to seems to be a client-side no-op on both firefox & chrome.
          query_values.delete("redirect_to")

          @parsed_url.query_values = query_values.empty? ? nil : query_values
        end
        @url = @parsed_url.to_s
      end
    end
  end
end
