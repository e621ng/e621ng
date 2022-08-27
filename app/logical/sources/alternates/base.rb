module Sources
  module Alternates
    class Base
      attr_reader :url, :gallery_url, :submission_url, :direct_url, :additional_urls, :parsed_url

      def initialize(url)
        @url = url

        @parsed_url = Addressable::URI.heuristic_parse(url) rescue nil

        if @parsed_url.present?
          if force_https?
            @parsed_url.scheme = "https"
            @url = @parsed_url.to_s
          end

          parse
        end
      end

      def force_https?
        return false unless @parsed_url.present?
        secure_domains = %w[weasyl.com e-hentai.org hentai-foundry.com paheal.net imgur.com]
        secure_domains.include?(@parsed_url.domain)
      end

      def match?
        return false if parsed_url.nil?
        parsed_url.domain.in?(domains)
      end

      def domains
        []
      end

      def parse

      end

      def remove_duplicates(sources)
        sources
      end

      def original_url
        @url[0..2048] # Truncate to prevent abuse
      end
    end
  end
end
