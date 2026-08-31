# frozen_string_literal: true

# One-time seed of user_ip_addresses from the existing per-record IP columns,
# restricted to the retention window. Run once, off-peak. Deliberately NOT
# idempotent: re-running a source that already completed doubles its hit_count
# contributions. If a run fails partway, clear user_ip_addresses and start over
# (the table is fully reconstructible from these sources plus the live writes).
class UserIpAddressBackfillJob < ApplicationJob
  sidekiq_options queue: "low_prio"

  BATCH_SIZE = 100_000

  # Each source contributes (user, ip, timestamp) tuples. `where` is an extra
  # predicate on the source, already qualified to the `t` alias below.
  SOURCES = [
    { table: "comments",           user: "creator_id",  ip: "creator_ip_addr", ts: "created_at" },
    # Dmails are stored once per participant and both copies carry from_id /
    # creator_ip_addr; without this filter every sent dmail counts twice.
    { table: "dmails",             user: "from_id",     ip: "creator_ip_addr", ts: "created_at", where: "t.owner_id = t.from_id" },
    { table: "blips",              user: "creator_id",  ip: "creator_ip_addr", ts: "created_at" },
    { table: "post_flags",         user: "creator_id",  ip: "creator_ip_addr", ts: "created_at" },
    { table: "posts",              user: "uploader_id", ip: "uploader_ip_addr", ts: "created_at" },
    { table: "post_votes",         user: "user_id",     ip: "user_ip_addr",    ts: "created_at" },
    { table: "comment_votes",      user: "user_id",     ip: "user_ip_addr",    ts: "created_at" },
    { table: "forum_posts",        user: "creator_id",  ip: "creator_ip_addr", ts: "created_at" },
    { table: "forum_topics",       user: "creator_id",  ip: "creator_ip_addr", ts: "created_at" },
    { table: "tickets",            user: "creator_id",  ip: "creator_ip_addr", ts: "created_at" },
    { table: "artist_versions",    user: "updater_id",  ip: "updater_ip_addr", ts: "created_at" },
    { table: "note_versions",      user: "updater_id",  ip: "updater_ip_addr", ts: "created_at" },
    { table: "pool_versions",      user: "updater_id",  ip: "updater_ip_addr", ts: "created_at" },
    # post_versions has no created_at, defaults updater_ip_addr to 127.0.0.1
    # (dropped by the loopback filter) and updater_id to 0 (dropped by the FK
    # join to users).
    { table: "post_versions",      user: "updater_id",  ip: "updater_ip_addr", ts: "updated_at" },
    { table: "wiki_page_versions", user: "updater_id",  ip: "updater_ip_addr", ts: "created_at" },
    # A user's last login: one row seen at last_logged_in_at.
    { table: "users",              user: "id",          ip: "last_ip_addr",    ts: "last_logged_in_at" },
  ].freeze

  # Private / loopback / link-local ranges to exclude, both families. Cross-family
  # <<= returns false (verified), so listing v4 and v6 ranges together is safe.
  NON_PUBLIC_RANGES = %w[
    10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8 169.254.0.0/16
    ::1/128 fc00::/7 fe80::/10
  ].freeze

  def perform
    cutoff = Danbooru.config.user_ip_retention_period.ago
    UserIpAddress.without_timeout do
      SOURCES.each { |source| backfill_source(source, cutoff) }
    end
  end

  private

  def connection
    UserIpAddress.connection
  end

  def backfill_source(source, cutoff)
    table = source[:table]
    max_id = connection.select_value("SELECT MAX(id) FROM #{table}").to_i
    (0..max_id).step(BATCH_SIZE) do |start_id|
      connection.execute(batch_sql(source, cutoff, start_id, start_id + BATCH_SIZE))
    end
    Rails.logger.info("UserIpAddressBackfillJob: finished #{table} (max_id=#{max_id})")
  end

  # Aggregates one id-range into user_ip_addresses. ON CONFLICT merges across
  # batches and across source tables, so batching is safe.
  def batch_sql(source, cutoff, start_id, end_id)
    table, user_col, ip_col, ts_col = source.values_at(:table, :user, :ip, :ts)
    normalized_ip = normalize_ip("t.#{ip_col}")
    extra = source[:where] ? "AND #{source[:where]}" : ""
    <<~SQL.squish
      INSERT INTO user_ip_addresses (user_id, ip_addr, first_seen_at, last_seen_at, hit_count)
      SELECT uid, nip, MIN(ts), MAX(ts), COUNT(*)
      FROM (
        SELECT u.id AS uid, #{normalized_ip} AS nip, t.#{ts_col} AS ts
        FROM #{table} t
        INNER JOIN users u ON u.id = t.#{user_col}
        WHERE t.id >= #{start_id.to_i} AND t.id < #{end_id.to_i}
          AND t.#{ip_col} IS NOT NULL
          AND t.#{ts_col} IS NOT NULL
          AND t.#{ts_col} > #{connection.quote(cutoff)}
          #{extra}
      ) s
      WHERE #{public_only('nip')}
      GROUP BY uid, nip
      ON CONFLICT (user_id, ip_addr) DO UPDATE SET
        first_seen_at = LEAST(user_ip_addresses.first_seen_at, excluded.first_seen_at),
        last_seen_at  = GREATEST(user_ip_addresses.last_seen_at, excluded.last_seen_at),
        hit_count     = user_ip_addresses.hit_count + excluded.hit_count
    SQL
  end

  # Normalize IPv4-mapped IPv6 (::ffff:a.b.c.d -> a.b.c.d) to match the live
  # write path, so a client never splits into a mapped and an unmapped identity.
  def normalize_ip(expr)
    "CASE WHEN #{expr} <<= inet '::ffff:0:0/96' " \
      "THEN (inet '0.0.0.0' + (#{expr} - inet '::ffff:0.0.0.0')) " \
      "ELSE #{expr} END"
  end

  def public_only(expr)
    clauses = NON_PUBLIC_RANGES.map { |range| "#{expr} <<= inet '#{range}'" }.join(" OR ")
    "NOT (#{clauses})"
  end
end
