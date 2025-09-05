# frozen_string_literal: true

module Sources
  module Alternates
    class Inkbunny < Base
      def force_https?
        true
      end

      def domains
        ["inkbunny.net", "metapix.net"]
      end

      def original_url
        # Remove anchor
        if @parsed_url.fragment.present?
          @parsed_url.fragment = nil
        end

        # Remove trailing dash
        if @parsed_url.path.present? && @parsed_url.path.end_with?("-")
          @parsed_url.path = @parsed_url.path.chomp("-")
        end

        @url = @parsed_url.to_s
      end
    end
  end
end
