# frozen_string_literal: true

class SearchTrend < ApplicationRecord
  WINDOW_HOURS = 12

  validates :tag, presence: true, tag_name: true, on: :create
  validates :tag, length: { in: 1..100 }
  validates :day, presence: true
  validates :hour, numericality: { only_integer: true, in: 0..23 }, allow_nil: true

  # Returns all records for a given day (both hourly and daily aggregate records).
  scope :for_day, ->(day) { where(day: day.to_date) }

  # Returns per-tag totals for a given day, aggregating hourly records where present.
  # Ordered by count descending, then tag ascending.
  # Uses a subquery so that the paginator's COUNT(*) targets the subquery alias rather
  # than the raw table (avoids GROUP BY + aggregate SELECT + COUNT(*) conflicts).
  scope :for_day_totals, ->(day) {
    quoted = connection.quote(day.to_date)
    subquery = <<~SQL.squish
      SELECT tag, day, SUM(count)::integer AS count
      FROM search_trends
      WHERE day = #{quoted}
      GROUP BY tag, day
    SQL
    from("(#{subquery}) AS search_trends").order(Arel.sql("count DESC, tag ASC"))
  }

  # Increment the hourly count for a tag. Sanitizes tag to downcase.
  def self.increment!(tag, day: Time.now.utc.to_date, ip: nil)
    t = tag.to_s.downcase.strip
    return if t.blank?
    return unless Setting.trends_enabled
    return unless valid_tag?(t)
    return if SearchTrendBlacklist.blacklisted?(t)

    # Rate limiting checks
    if ip.present?
      ip_key = "trends:ip:#{ip}"
      return if RateLimiter.check_limit(ip_key, Setting.trends_ip_limit, Setting.trends_ip_window.seconds)
    end

    tag_key = "trends:tag:#{t}"
    return if RateLimiter.check_limit(tag_key, Setting.trends_tag_limit, Setting.trends_tag_window.seconds)

    now  = Time.now.utc
    date = day.to_date
    hour = now.hour
    values_sql = "(#{connection.quote(t)}, #{connection.quote(date)}, #{hour}, 1, #{connection.quote(now)}, #{connection.quote(now)})"
    sql = <<~SQL.squish
      INSERT INTO search_trends (tag, day, hour, count, created_at, updated_at)
      VALUES #{values_sql}
      ON CONFLICT (tag, day, hour) WHERE hour IS NOT NULL
      DO UPDATE SET count = search_trends.count + 1, updated_at = EXCLUDED.updated_at
    SQL
    connection.execute(sql)

    # Increment rate limit counters after successful database operation
    RateLimiter.hit(ip_key, Setting.trends_ip_window.seconds) if ip.present?
    RateLimiter.hit(tag_key, Setting.trends_tag_window.seconds)
  end

  # Parse a raw tag query string, extract plain affirmative tags, and record them.
  # Tags with a `-` prefix (negated) are excluded entirely; tags with only a `~` prefix
  # have that prefix stripped before recording. Metatags (containing `:`) are ignored.
  # Errors in query parsing are logged and swallowed so the caller is never disrupted.
  def self.record_query!(query, day: Time.now.utc.to_date, ip: nil)
    return if query.blank?

    tokens = TagQuery.scan_recursive(
      query,
      flatten: true,
      strip_prefixes: false,
      delimit_groups: true,
      sort_at_level: false,
      normalize_at_level: true,
      strip_duplicates_at_level: true,
    )

    negated_stack = []
    tag_tokens = tokens.filter_map do |t|
      next if t.blank?
      if t.end_with?("(")
        negated_stack.push(t[/\A[-~]*/].include?("-") || negated_stack.last == true)
        next
      end
      if t == ")"
        negated_stack.pop
        next
      end
      next if t.include?(":") # skip metatags
      prefix = t[/\A[-~]*/]
      next if prefix.include?("-") || negated_stack.last == true
      t[prefix.length..].presence
    end

    bulk_increment!(tag_tokens, day: day, ip: ip) if tag_tokens.present?
  rescue StandardError => e
    Rails.logger.warn("Failed to record search trends for query #{query.inspect}: #{e.class}: #{e.message}")
  end

  # Bulk increment hourly counts for an array of tags. Upsert w/ increment on conflict.
  def self.bulk_increment!(tags, day: Time.now.utc.to_date, ip: nil)
    ts = Array(tags).map { |tg| tg.to_s.downcase.strip }.select(&:present?).uniq
    return if ts.empty?
    return unless Setting.trends_enabled

    ts.select! { |tg| valid_tag?(tg) }
    return if ts.empty?

    # Rate limiting checks
    if ip.present?
      ip_key = "trends:ip:#{ip}"
      return if RateLimiter.check_limit(ip_key, Setting.trends_ip_limit, Setting.trends_ip_window.seconds)
    end

    # Fetch blacklist patterns once for the whole batch
    blacklist_patterns = SearchTrendBlacklist.cached_patterns

    # Filter out blacklisted tags and tags that would exceed tag-specific rate limits
    allowed_tags = ts.reject do |tag|
      next true if blacklist_patterns.any? { |pat| File.fnmatch(pat, tag, File::FNM_CASEFOLD) }

      tag_key = "trends:tag:#{tag}"
      RateLimiter.check_limit(tag_key, Setting.trends_tag_limit, Setting.trends_tag_window.seconds)
    end

    return if allowed_tags.empty?

    now  = Time.now.utc
    date = day.to_date
    hour = now.hour
    values_sql = allowed_tags.map { |tg| "(#{connection.quote(tg)}, #{connection.quote(date)}, #{hour}, 1, #{connection.quote(now)}, #{connection.quote(now)})" }.join(", ")
    sql = <<~SQL.squish
      INSERT INTO search_trends (tag, day, hour, count, created_at, updated_at)
      VALUES #{values_sql}
      ON CONFLICT (tag, day, hour) WHERE hour IS NOT NULL
      DO UPDATE SET count = search_trends.count + 1, updated_at = EXCLUDED.updated_at
    SQL
    connection.execute(sql)

    # Increment rate limit counters after successful database operation
    RateLimiter.hit(ip_key, Setting.trends_ip_window.seconds) if ip.present?
    allowed_tags.each do |tag|
      tag_key = "trends:tag:#{tag}"
      RateLimiter.hit(tag_key, Setting.trends_tag_window.seconds)
    end
  end

  # Coalesce hourly records older than `before` into daily aggregate records, then delete
  # the originals. Called during daily maintenance so the hourly buffer stays bounded.
  def self.coalesce_hourly!(before: Time.now.utc - 48.hours)
    cutoff      = before
    cutoff_day  = cutoff.utc.to_date
    cutoff_hour = cutoff.utc.hour
    now         = Time.now.utc

    # Step 1: merge hourly totals into daily records (upsert, adding to any existing count).
    connection.execute(<<~SQL.squish)
      INSERT INTO search_trends (tag, day, hour, count, created_at, updated_at)
      SELECT   tag, day, NULL, SUM(count)::integer, #{connection.quote(now)}, #{connection.quote(now)}
      FROM     search_trends
      WHERE    hour IS NOT NULL
        AND    (day < #{connection.quote(cutoff_day)}
                OR (day = #{connection.quote(cutoff_day)} AND hour <= #{cutoff_hour}))
      GROUP BY tag, day
      ON CONFLICT (tag, day) WHERE hour IS NULL
      DO UPDATE SET count      = search_trends.count + EXCLUDED.count,
                    updated_at = EXCLUDED.updated_at
    SQL

    # Step 2: delete the coalesced hourly records.
    where(
      "hour IS NOT NULL AND (day < ? OR (day = ? AND hour <= ?))",
      cutoff_day, cutoff_day, cutoff_hour
    ).delete_all
  end

  # Delete daily aggregate records from before today that fall below the minimum count.
  # Hourly records are managed exclusively by coalesce_hourly! and are never pruned here.
  def self.prune!(min_count: Danbooru.config.search_trend_minimum_count)
    where("hour IS NULL AND day < ? AND count < ?", Time.now.utc.to_date, min_count)
      .in_batches(load: false)
      .delete_all
  end

  private_class_method def self.valid_tag?(tag)
    return false unless tag.length.between?(1, 100)
    record = new(tag: tag, day: Time.now.utc.to_date)
    TagNameValidator.new(attributes: [:tag]).validate_each(record, :tag, tag)
    record.errors[:tag].empty?
  end

  # Top tags for a given day by total search count, aggregated across any hourly records.
  def self.top_for_day(day: Time.now.utc.to_date, limit: 100)
    for_day_totals(day).limit(limit)
  end

  # Rising tags: tags whose search volume in the last `WINDOW_HOURS` hours is meaningfully
  # higher than the same window 24 hours prior. Uses hourly records only.
  #
  # Both sides of the comparison span the same number of hours, eliminating the partial-day
  # bias inherent in a simple today-vs-yesterday daily comparison.
  def self.rising(at: Time.now.utc, limit: 10, min_today: 10, min_delta: 10, min_ratio: 2.0)
    h = at.hour
    d = at.to_date

    today_cond = hourly_window_sql(d, h, WINDOW_HOURS)
    prev_cond  = hourly_window_sql(d - 1.day, h, WINDOW_HOURS)

    min_today_v = min_today.to_i
    min_delta_v = min_delta.to_i
    min_ratio_v = min_ratio.to_f
    limit_v     = limit.to_i

    subquery = <<~SQL.squish
      WITH today_totals AS (
        SELECT tag, SUM(count) AS c
        FROM   search_trends
        WHERE  hour IS NOT NULL AND (#{today_cond})
        GROUP  BY tag
      ),
      prev_totals AS (
        SELECT tag, SUM(count) AS c
        FROM   search_trends
        WHERE  hour IS NOT NULL AND (#{prev_cond})
        GROUP  BY tag
      )
      SELECT t.tag, t.c AS count
      FROM   today_totals t
      LEFT   JOIN prev_totals y ON y.tag = t.tag
      WHERE  t.c >= #{min_today_v}
        AND  (
               t.c - COALESCE(y.c, 0) >= #{min_delta_v}
               OR (COALESCE(y.c, 0) > 0 AND t.c::numeric / NULLIF(y.c, 0) >= #{min_ratio_v})
             )
      ORDER  BY count DESC, tag ASC
      LIMIT  #{limit_v}
    SQL

    select("tag, count::integer").from("(#{subquery}) AS search_trends")
  end

  def self.rising_tags_list
    Cache.fetch("rising_tags", expires_in: 15.minutes) do
      tags = SearchTrend.rising(min_today: Setting.trends_min_today, min_delta: Setting.trends_min_delta, min_ratio: Setting.trends_min_ratio).pluck(:tag)
      TagAlias.to_aliased(tags)
    end
  end

  # Returns a SQL fragment that matches hourly records within a `window_hours`-wide window
  # ending at (day, hour). The window may span midnight into the previous day.
  private_class_method def self.hourly_window_sql(day, hour, window_hours)
    start_hour = hour - window_hours + 1
    if start_hour >= 0
      "day = #{connection.quote(day)} AND hour BETWEEN #{start_hour} AND #{hour}"
    else
      prev_day        = day - 1.day
      prev_start_hour = 24 + start_hour # start_hour is negative, so this is < 24
      "(day = #{connection.quote(day)} AND hour <= #{hour}) " \
        "OR (day = #{connection.quote(prev_day)} AND hour >= #{prev_start_hour})"
    end
  end
end
