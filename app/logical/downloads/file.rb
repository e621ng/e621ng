# frozen_string_literal: true

module Downloads
  class File
    include ActiveModel::Validations
    class Error < Exception ; end

    RETRIABLE_ERRORS = [Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::EIO, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Timeout::Error, IOError]

    attr_reader :url

    validate :validate_url

    def initialize(url)
      begin
        unencoded = Addressable::URI.unencode(url)
        escaped = Addressable::URI.escape(unencoded)
        @url = Addressable::URI.parse(escaped)
      rescue Addressable::URI::InvalidURIError
        @url = nil
      end
      validate!
    end

    def size
      res = HTTParty.head(uncached_url, **httparty_options, timeout: 3)

      if res.success?
        res.content_length
      else
        raise HTTParty::ResponseError.new(res)
      end
    end

    def download!(tries: 3, **)
      Retriable.retriable(on: RETRIABLE_ERRORS, tries: tries, base_interval: 0) do
        http_get_streaming(uncached_url, **)
      end
    end

    def validate_url
      errors.add(:base, "URL must not be blank") if url.blank?
      errors.add(:base, "'#{url}' is not a valid url") if !url.host.present?
      errors.add(:base, "'#{url}' is not a valid url. Did you mean 'http://#{url}'?") if !url.scheme.in?(%w[http https])
      valid, reason = UploadWhitelist.is_whitelisted?(url)
      errors.add(:base, "'#{url}' is not whitelisted and can't be direct downloaded: #{reason}") if !valid
    end

    def http_get_streaming(url, file: Tempfile.new(binmode: true), max_size: Danbooru.config.max_file_size)
      size = 0

      res = HTTParty.get(url, httparty_options) do |chunk|
        next if [301, 302].include?(chunk.code)

        size += chunk.size
        raise Error.new("File is too large (max size: #{max_size})") if size > max_size && max_size > 0

        file.write(chunk)
      end

      if res.success?
        file.rewind
        return file
      else
        raise Error.new("HTTP error code: #{res.code} #{res.message}")
      end
    end # def

    # Prevent Cloudflare from potentially mangling the image. See issue #3528.
    def uncached_url
      return file_url unless is_cloudflare?(file_url)

      url = file_url.dup
      url.query_values = url.query_values.to_h.merge(danbooru_no_cache: SecureRandom.uuid)
      url
    end

    def file_url
      @file_url ||= Addressable::URI.parse(strategy.image_url)
    end

    def strategy
      @strategy ||= Sources::Strategies.find(url.to_s)
    end

    def httparty_options
      {
        timeout: 10,
        stream_body: true,
        headers: strategy.headers,
        connection_adapter: ValidatingConnectionAdapter,
      }.deep_merge(Danbooru.config.httparty_options)
    end

    def is_cloudflare?(url)
      ip_addr = IPAddr.new(Resolv.getaddress(url.hostname))
      CloudflareService.ips.any? { |subnet| subnet.include?(ip_addr) }
    end
  end

  # Hook into HTTParty to validate the IP before following redirects.
  # https://www.rubydoc.info/github/jnunemaker/httparty/HTTParty/ConnectionAdapter
  class ValidatingConnectionAdapter < HTTParty::ConnectionAdapter
    def self.call(uri, options)
      ip_addr = IPAddr.new(Resolv.getaddress(uri.hostname))

      if ip_blocked?(ip_addr)
        raise Downloads::File::Error, "Downloads from #{ip_addr} are not allowed"
      end

      # Check whitelist here again, in case of open redirect vulnerabilities
      valid, _reason = UploadWhitelist.is_whitelisted?(Addressable::URI.parse(uri))
      unless valid
        raise Downloads::File::Error, "'#{uri}' is not whitelisted and can't be direct downloaded"
      end

      super(uri, options)
    end

    def self.ip_blocked?(ip_addr)
      ip_addr.private? || ip_addr.loopback? || ip_addr.link_local?
    end
  end
end
