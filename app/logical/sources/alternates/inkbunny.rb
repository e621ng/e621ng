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
          @url = @parsed_url.to_s
        end

        @url
      end
    end
  end
end
