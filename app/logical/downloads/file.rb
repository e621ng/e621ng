# frozen_string_literal: true

module Downloads
  class File
    include ActiveModel::Validations
    class Error < Exception ; end

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

    def download!(max_size: Danbooru.config.max_file_size)
      file = Tempfile.new(binmode: true)
      conn = Faraday.new(Danbooru.config.faraday_options) do |f|
        f.response :follow_redirects, callback: ->(_old_env, new_env) { validate_uri_allowed!(new_env.url) }
        f.request :retry, max: 3, retry_block: ->(*) { file = Tempfile.new(binmode: true) }
      end

      res = conn.get(uncached_url, nil, strategy.headers) do |req|
        req.options.on_data = ->(chunk, overall_recieved_bytes, env) do
          next if [301, 302].include?(env.status)

          raise Error, "File is too large (max size: #{max_size})" if overall_recieved_bytes > max_size
          file.write(chunk)
        end
      end
      raise Error, "HTTP error code: #{res.status} #{Rack::Utils::HTTP_STATUS_CODES[res.status]}" unless res.success?

      file.rewind
      file
    end

    def validate_url
      errors.add(:base, "URL must not be blank") if url.blank?
      errors.add(:base, "'#{url}' is not a valid url") if !url.host.present?
      errors.add(:base, "'#{url}' is not a valid url. Did you mean 'http://#{url}'?") if !url.scheme.in?(%w[http https])
      validate_uri_allowed!(url)
    end

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

    def is_cloudflare?(url)
      ip_addr = IPAddr.new(Resolv.getaddress(url.hostname))
      CloudflareService.ips.any? { |subnet| subnet.include?(ip_addr) }
    end

    def validate_uri_allowed!(uri)
      ip_addr = IPAddr.new(Resolv.getaddress(uri.hostname))
      if ip_addr.private? || ip_addr.loopback? || ip_addr.link_local?
        raise Downloads::File::Error, "Downloads from #{ip_addr} are not allowed"
      end

      valid, _reason = UploadWhitelist.is_whitelisted?(uri)
      unless valid
        raise Downloads::File::Error, "'#{uri}' is not whitelisted and can't be direct downloaded"
      end
    end
  end
end
