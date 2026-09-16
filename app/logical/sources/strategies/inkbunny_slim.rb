# frozen_string_literal: true

# Inkbunny
#
# Image files are served from metapix.net subdomains and require
# "https://inkbunny.net" as the referer, per https://wiki.inkbunny.net/wiki/API
#
# * https://us.ib.metapix.net/files/full/5604/5604180_ColdBloodedTwilight_2025.png
# * https://us.ib.metapix.net/files/screen/5604/5604180_ColdBloodedTwilight_2025_474.png
#
# * https://inkbunny.net/s/3200751

module Sources
  module Strategies
    class InkbunnySlim < Base
      def domains
        ["inkbunny.net", "metapix.net"]
      end

      def canonical_url
        image_url
      end

      def image_urls
        [url]
      end

      def headers
        { referer: "https://inkbunny.net" }
      end
    end
  end
end
