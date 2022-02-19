module Sources
  module Strategies
    class Null < Base
      def image_urls
        [url]
      end

      def page_url
        url
      end

      def canonical_url
        image_url
      end

      def normalize_for_artist_finder
        url
      end
    end
  end
end
