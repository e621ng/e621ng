# frozen_string_literal: true

module Sources
  module Alternates
    class Base
      attr_reader :url, :gallery_url, :submission_url, :direct_url, :additional_urls, :parsed_url

      def initialize(url)
        if force_https?
          url.gsub!(/\Ahttp:/, "https:")
        end
        @url = url

        @parsed_url = Addressable::URI.heuristic_parse(url) rescue nil

        parse if @parsed_url.present?
      end

      def force_https?
        false
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
