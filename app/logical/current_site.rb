# frozen_string_literal: true

# The site the current request (or job) is served as (doc 38).
# One deployment serves the primary site plus any `Danbooru.config.site_profiles`.
# Resolved per request by Middleware::SiteResolver; jobs use `with`.
class CurrentSite
  Profile = Data.define(:id, :hosts, :safe_mode, :overrides) do
    def primary?
      id == Danbooru.config.primary_site
    end
  end

  class << self
    def primary
      Profile.new(id: Danbooru.config.primary_site, hosts: [].freeze, safe_mode: false, overrides: {}.freeze)
    end

    # Parsed on demand, not memoized: the config can be stubbed in specs.
    def profiles
      Danbooru.config.site_profiles.map do |id, profile|
        Profile.new(
          id: id,
          hosts: profile[:hosts].map(&:downcase).freeze,
          safe_mode: profile[:safe_mode] == true,
          overrides: deep_freeze(profile.fetch(:overrides, {}).deep_dup),
        )
      end
    end

    # Primary first.
    def ids
      [Danbooru.config.primary_site, *profiles.map(&:id)]
    end

    # Every value `cache_key` can take, for invalidating per-site cache entries.
    def cache_keys
      [nil, *profiles.map(&:id)]
    end

    def find(id)
      return primary if id.nil? || id == Danbooru.config.primary_site
      profiles.find { |profile| profile.id == id }
    end

    def for_host(host)
      profiles.find { |profile| profile.hosts.include?(host) }
    end

    # Returns [profile, safe_mode], or :unknown for a header naming no site.
    # The header names the site; the Host is a backstop. Safe mode is ORed so
    # a missing or wrong value on either side errs towards safe mode.
    def resolve(header:, host:)
      header_site = nil
      if header.present?
        header_site = find(header)
        # With no profiles configured the header is ignored, so nothing changes
        # until the load balancer is in charge of it.
        return :unknown if header_site.nil? && profiles.any?
      end
      host_site = host.present? ? for_host(host) : nil

      site = header_site || host_site || primary
      safe = header_site&.safe_mode || host_site&.safe_mode || false
      [site, safe]
    end

    def apply!(site, safe)
      RequestStore[:current_site] = site
      RequestStore[:site_safe_mode] = safe
    end

    def current
      RequestStore[:current_site] || primary
    end

    delegate :id, :primary?, to: :current

    # nil on the primary site, so existing cache keys stay unchanged.
    def cache_key
      primary? ? nil : id
    end

    # The only reader of Danbooru.config.safe_mode?, kept so a deployment
    # configured as a safe-mode site (the old e926 box) still forces it.
    def safe_mode?
      RequestStore[:site_safe_mode] || current.safe_mode || (primary? && Danbooru.config.safe_mode?) || false
    end

    # Runs the block as the given site (nil for primary), including its safe
    # mode, then restores the previous state. Raises for an unknown site.
    def with(site_id)
      site = find(site_id)
      raise ArgumentError, "Unknown site: #{site_id}" if site.nil?

      previous = [RequestStore[:current_site], RequestStore[:site_safe_mode], CurrentUser.safe_mode?]
      apply!(site, site.safe_mode)
      CurrentUser.safe_mode = safe_mode?
      yield
    ensure
      if previous
        RequestStore[:current_site] = previous[0]
        RequestStore[:site_safe_mode] = previous[1]
        CurrentUser.safe_mode = previous[2]
      end
    end

    private

    # Overrides are returned straight from the config dispatcher, so callers
    # must not be able to mutate them.
    def deep_freeze(value)
      case value
      when Hash then value.each_value { |v| deep_freeze(v) }
      when Array then value.each { |v| deep_freeze(v) }
      end
      value.freeze
    end
  end
end
