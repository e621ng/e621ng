# frozen_string_literal: true

# Records which IP addresses a user is seen using, one debounced upsert per
# (user, ip) per hour. Feeds UserAltFinder. Called from SessionLoader on every
# authenticated request; any failure is swallowed so tracking can never break
# request processing.
module UserIpTracker
  DEBOUNCE = 1.hour

  def self.track!(user, ip_addr)
    return unless Danbooru.config.enable_user_ip_tracking?
    return if user.nil? || user.is_anonymous?

    # Normalize IPv4-mapped IPv6 (::ffff:a.b.c.d -> a.b.c.d): the mapped form
    # has family() = 6, so its /64 would be ::/64 (one bucket for every mapped
    # address) and as an exact inet it does not equal its plain v4 form,
    # splitting one client into two identities. Skip non-public addresses
    # entirely, matching AsnRange.lookup.
    ip = IPAddr.new(ip_addr.to_s).native
    return if ip.private? || ip.loopback? || ip.link_local?

    ip_string = ip.to_s
    cache_key = "user_ip:#{user.id}:#{ip_string}"
    return if Cache.fetch(cache_key)

    Cache.write(cache_key, true, expires_in: DEBOUNCE)

    now = Time.now
    UserIpAddress.upsert(
      { user_id: user.id, ip_addr: ip_string, first_seen_at: now, last_seen_at: now },
      unique_by: %i[user_id ip_addr],
      on_duplicate: Arel.sql(
        "last_seen_at = excluded.last_seen_at, hit_count = user_ip_addresses.hit_count + 1",
      ),
    )
  rescue StandardError => e
    DanbooruLogger.log(e)
    nil
  end
end
