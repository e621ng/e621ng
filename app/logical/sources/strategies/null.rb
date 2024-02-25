# frozen_string_literal: true

module Sources
  module Strategies
    class Null < Base
      def image_urls
        [url]
      end

      def canonical_url
        image_url
      end
    end
  end
end
