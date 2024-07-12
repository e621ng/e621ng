# frozen_string_literal: true

# This is a collection of strategies for extracting information about a 
# resource. At a minimum it tries to extract the artist name and a canonical 
# URL to download the image from. But it can also be used to normalize a URL 
# for use with the artist finder. 
#
# Design Principles
#
# In general you should minimize state. You can safely assume that <tt>url</tt>
# will not change over the lifetime of an instance,
# so you can safely memoize methods and their results. A common pattern is
# conditionally making an external API call and parsing its response. You should
# make this call on demand and memoize the response.

module Sources
  module Strategies
    class Base
      attr_reader :url, :urls, :parsed_url

      # * <tt>url</tt> - Should point to a resource suitable for 
      #   downloading. This may sometimes point to the binary file. 
      #   It may also point to the artist's profile page, in cases
      #   where this class is being used to normalize artist urls.
      #   Implementations should be smart enough to detect this and 
      #   behave accordingly.
      def initialize(url)
        @url = url
        @urls = [url].select(&:present?)

        @parsed_url = Addressable::URI.heuristic_parse(url) rescue nil
      end

      # Should return true if this strategy should be used. By default, checks
      # if the main url belongs to any of the domains associated with this site.
      def match?
        return false if parsed_url.nil?
        parsed_url.domain.in?(domains)
      end

      # The list of base domains belonging to this site. Subdomains are
      # automatically included (i.e. "pixiv.net" matches "fanbox.pixiv.net").
      def domains
        []
      end

      # Whatever <tt>url</tt> is, this method should return the direct links 
      # to the canonical binary files. It should not be an HTML page. It should 
      # be a list of JPEG, PNG, GIF, WEBM, MP4, ZIP, etc. It is what the 
      # downloader will fetch and save to disk.
      def image_urls
        raise NotImplementedError
      end

      def image_url
        image_urls.first
      end

      # A smaller representation of the image that's suitable for
      # displaying previews.
      def preview_urls
        image_urls
      end

      def preview_url
        preview_urls.first
      end

      # This will be the url stored in posts. Typically this is the page
      # url, but on some sites it may be preferable to store the image url.
      def canonical_url
        image_url
      end

      # A name to suggest as the artist's tag name when creating a new artist.
      # This should usually be the artist's account name.
      def tag_name
        artist_name
      end

      # The artists's primary name. If an artist has both a display name and an
      # account name, this should be the display name.
      def artist_name
        nil
      end

      # A list of all names associated with the artist. These names will be suggested
      # as other names when creating a new artist.
      def other_names
        [artist_name, tag_name].compact.uniq
      end

      # Subclasses should merge in any required headers needed to access resources
      # on the site.
      def headers
        return Danbooru.config.http_headers
      end

      def file_url
        image_url
      end

      def data
        {}
      end

      def tags
        (@tags || []).uniq
      end

      def to_json
        to_h.to_json
      end
    end
  end
end
