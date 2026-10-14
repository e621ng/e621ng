# frozen_string_literal: true

module Downloads
  class File
    include ActiveModel::Validations
    class Error < StandardError; end

    # Internal/non-public address ranges that downloads must never reach. Includes
    # IPv6 transition and IPv4-mapped ranges, which IPAddr#private?/#loopback?/
    # #link_local? do not recognize even when they embed a blocked IPv4 target.
    BLOCKED_IP_RANGES = %w[
      0.0.0.0/8
      10.0.0.0/8
      100.64.0.0/10
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.168.0.0/16
      ::1/128
      fc00::/7
      fe80::/10
      ::/96
      ::ffff:0:0/96
      64:ff9b::/96
      64:ff9b:1::/48
      2002::/16
      2001::/32
    ].map { |range| IPAddr.new(range) }.freeze

    attr_reader :url

    validate :validate_url

    def initialize(url)
      begin
        uri = url.is_a?(Addressable::URI) ? url.dup : Addressable::URI.parse(url.to_s)
        @url = uri.normalize
      rescue Addressable::URI::InvalidURIError
        @url = nil
      end
      raise Error, errors.full_messages.join("; ") unless valid?
    end

    def download!(max_size: Danbooru.config.max_file_size, retries: 3)
      # Validate the actual URL we're about to fetch (which can differ from the source
      # url via the strategy's image_url) before opening any socket.
      validate_uri_allowed!(uncached_url)

      file = Tempfile.new(binmode: true)
      conn = Faraday.new(Danbooru.config.faraday_options) do |f|
        f.response :follow_redirects, callback: ->(_old_env, new_env) { validate_uri_allowed!(new_env.url) }
        f.request :retry, max: retries, retry_block: ->(*) { file = Tempfile.new(binmode: true) }
        # Pin the connection to a validated IP. The adapter block runs per request —
        # including every redirect and retry — so the exact address checked against
        # BLOCKED_IP_RANGES is the exact address connected to (no DNS-rebind window).
        f.adapter :net_http do |http|
          pin_connection!(http)
        end
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
    rescue Faraday::FollowRedirects::RedirectLimitReached
      file&.close!
      raise Error, "Could not download file: too many redirects"
    # Must come after the RedirectLimitReached clause, which is a Faraday::Error subclass.
    rescue Faraday::Error
      file&.close!
      raise Error, "Couldn't download the file. The remote server may be down or unreachable."
    end

    def validate_url
      if url.blank?
        errors.add(:base, "URL must not be blank")
        return
      end

      if url.scheme.in?(%w[http https])
        errors.add(:base, "'#{url}' is not a valid URL") if url.host.blank?
      elsif url.scheme.blank?
        errors.add(:base, "'#{url}' is not a valid URL. Did you mean 'http://#{url}'?")
      else
        errors.add(:base, "'#{url}' is not a valid URL. Only http and https are supported.")
      end
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
    rescue Resolv::ResolvError
      false
    end

    def validate_uri_allowed!(uri)
      return if uri.hostname.blank?

      resolve_and_validate_addresses!(uri.hostname)

      valid, _reason = UploadWhitelist.is_whitelisted?(uri)
      unless valid
        raise Downloads::File::Error, "'#{uri}' is not whitelisted and can't be direct downloaded"
      end
    end

    # Pin the underlying Net::HTTP connection to a validated IP so it can't be re-resolved
    # to a blocked address between validation and connect. Keeps the hostname as #address
    # (preserving TLS SNI and the Host header) while overriding only the socket target.
    def pin_connection!(http)
      return if http.address.blank?

      http.ipaddr = resolve_and_validate_addresses!(http.address)
    end

    # Resolve a host to its addresses and reject if ANY of them falls in a blocked range.
    # Fails closed on empty/failed resolution. Returns the address to connect to.
    def resolve_and_validate_addresses!(host)
      host = normalize_host(host)
      raise Downloads::File::Error, "Downloads from this address are not allowed" if host.blank?

      addresses = ip_literal?(host) ? [host] : Resolv.getaddresses(host)
      raise Downloads::File::Error, "Could not resolve '#{host}'" if addresses.blank?

      ip_addrs = addresses.map { |address| IPAddr.new(normalize_host(address)) }
      if ip_addrs.any? { |ip_addr| BLOCKED_IP_RANGES.any? { |range| range.include?(ip_addr) } }
        raise Downloads::File::Error, "Downloads from this address are not allowed"
      end

      # Pinning to a single IP loses the OS-level fallback across A/AAAA records that
      # connecting by hostname provided. Prefer an IPv4 record when both families are
      # present so an IPv6-only pin can't break downloads on hosts without a v6 route.
      (ip_addrs.find(&:ipv4?) || ip_addrs.first).to_s
    rescue Resolv::ResolvError, IPAddr::InvalidAddressError
      raise Downloads::File::Error, "Could not resolve '#{host}'"
    end

    # Strip the brackets Addressable/URI wrap around IPv6 literals so IPAddr and
    # Net::HTTP#ipaddr= (which both want a bare address) accept them.
    def normalize_host(host)
      host = host.to_s
      host.start_with?("[") && host.end_with?("]") ? host[1..-2] : host
    end

    def ip_literal?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
