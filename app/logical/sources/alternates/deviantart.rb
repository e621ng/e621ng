# frozen_string_literal: true

module Sources
  module Alternates
    class Deviantart < Base
      BASE_HOSTS = %w[deviantart.com www.deviantart.com].freeze

      def force_https?
        true
      end

      def domains
        ["deviantart.com"]
      end

      def original_url
        # Convert old-style subdomain sources to new-style folder links
        if BASE_HOSTS.exclude?(@parsed_url.host) && @parsed_url.host.present?
          username = @parsed_url.host.partition(".").first
          @parsed_url.host = "www.deviantart.com"
          @parsed_url.path = "/#{username}#{@parsed_url.path}"
          @url = @parsed_url.to_s
        end

        @url
      end
    end
  end
end
