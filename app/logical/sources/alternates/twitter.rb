# frozen_string_literal: true

module Sources
  module Alternates
    class Twitter < Base
      TWITFIX_DOMAINS = %w[fxtwitter.com fixupx.com vxtwitter.com twittpr.com].freeze
      # The list of nitter instances can be found at https://github.com/zedeus/nitter/wiki/Instances
      NITTER_HOSTS = %w[nitter.net nitter.poast.org nitter.space xcancel.com lightbrd.com nitter.tiekoetter.com nuku.trabun.org].freeze

      def force_https?
        true
      end

      def nitter_domains
        NITTER_HOSTS.map { |host| Addressable::URI.heuristic_parse(host).domain }
      end

      def domains
        ["twitter.com", "x.com", "twimg.com"] + TWITFIX_DOMAINS + nitter_domains
      end

      def original_url
        # Convert mobile URLs to base ones
        if @parsed_url.host == "mobile.twitter.com" || @parsed_url.host == "mobile.x.com"
          @parsed_url.host = "x.com"
        end
        # Convert twitter to 𝕏 links
        if @parsed_url.host == "twitter.com"
          @parsed_url.host = "x.com"
        end
        # Replace twitter embed-helper links with 𝕏 links
        if TWITFIX_DOMAINS.include?(@parsed_url.host)
          @parsed_url.host = "x.com"
        end
        # Replace nitter links with 𝕏 links, but allow other links on the same domain to skip later checks
        if nitter_domains.include?(@parsed_url.domain)
          if NITTER_HOSTS.include?(@parsed_url.host)
            if @parsed_url.path.start_with?("/pic/")
              @parsed_url.host = "pbs.twimg.com"
              @parsed_url.path = URI.decode_www_form_component(@parsed_url.path[4..])
              # URI must be re-parsed, to ensure query values are parsed
              @parsed_url = Addressable::URI.heuristic_parse(@parsed_url.to_s)
            else
              @parsed_url.host = "x.com"
            end
          else
            # Allow non-nitter subdomains, on the same domain, to avoid later handling here
            return @url
          end
        end
        # Remove tracking data from links
        if @parsed_url.domain == "x.com" && @parsed_url.query.present?
          query_values = @parsed_url.query_values || {}
          query_values.delete("s")
          query_values.delete("t")
          query_values.delete_if { |key, _| key.start_with?("utm_") }
          @parsed_url.query_values = query_values.empty? ? nil : query_values
        end
        # Remove photo specifier from links
        split_path = @parsed_url.path.split("/")
        if @parsed_url.domain == "x.com" && split_path.length == 6 && split_path[-2] == "photo"
          @parsed_url.path = split_path[0..-3].join("/")
        end
        # Update old direct image URLs
        if @parsed_url.host == "pbs.twimg.com"
          query_values = @parsed_url.query_values || {}
          # Parse the name part of the query, old format was ":orig"
          if @parsed_url.path.include?(":")
            query_values["name"] = @parsed_url.path.rpartition(":").last
            @parsed_url.path = @parsed_url.path.rpartition(":").first
            @parsed_url.query_values = query_values
          end
          # Parse the format part of the query, old format was the file extension, ".jpg"
          if @parsed_url.extname.present?
            query_values["format"] = @parsed_url.extname[1..]
            @parsed_url.path = @parsed_url.path.delete_suffix(@parsed_url.extname)
            @parsed_url.query_values = query_values
          end
        end

        @url = @parsed_url.to_s
      end
    end
  end
end
