# frozen_string_literal: true

class SearchTrend < ApplicationRecord
  validates :tag, presence: true
  validates :day, presence: true

  scope :for_day, ->(day) { where(day: day.to_date) }

  # Increment count for tag on a given day (default: today). Sanitizes tag to downcase.
  def self.increment!(tag, day: Date.current, ip: nil)
    t = tag.to_s.downcase.strip
    return if t.blank?
    return unless Setting.trends_enabled

    # Rate limiting checks
    if ip.present?
      ip_key = "trends:ip:#{ip}"
      return if RateLimiter.check_limit(ip_key, Setting.trends_ip_limit, Setting.trends_ip_window.seconds)
    end

    tag_key = "trends:tag:#{t}"
    return if RateLimiter.check_limit(tag_key, Setting.trends_tag_limit, Setting.trends_tag_window.seconds)

    date = day.to_date
    now = Time.current
    values_sql = "(#{connection.quote(t)}, #{connection.quote(date)}, 1, #{connection.quote(now)}, #{connection.quote(now)})"
    sql = <<~SQL.squish
      INSERT INTO search_trends (tag, day, count, created_at, updated_at)
      VALUES #{values_sql}
      ON CONFLICT (tag, day)
      DO UPDATE SET count = search_trends.count + 1, updated_at = EXCLUDED.updated_at
    SQL
    connection.execute(sql)

    # Increment rate limit counters after successful database operation
    RateLimiter.hit(ip_key, Setting.trends_ip_window.seconds) if ip.present?
    RateLimiter.hit(tag_key, Setting.trends_tag_window.seconds)
  end

  # Bulk increment for an array of tags for the day. Upsert w/ increment on conflict.
  def self.bulk_increment!(tags, day: Date.current, ip: nil)
    ts = Array(tags).map { |tg| tg.to_s.downcase.strip }.select(&:present?).uniq
    return if ts.empty?
    return unless Setting.trends_enabled

    # Rate limiting checks
    if ip.present?
      ip_key = "trends:ip:#{ip}"
      return if RateLimiter.check_limit(ip_key, Setting.trends_ip_limit, Setting.trends_ip_window.seconds)
    end

    # Filter out tags that would exceed tag-specific rate limits
    allowed_tags = ts.select do |tag|
      tag_key = "trends:tag:#{tag}"
      !RateLimiter.check_limit(tag_key, Setting.trends_tag_limit, Setting.trends_tag_window.seconds)
    end

    return if allowed_tags.empty?

    date = day.to_date
    now = Time.current
    values_sql = allowed_tags.map { |tg| "(#{connection.quote(tg)}, #{connection.quote(date)}, 1, #{connection.quote(now)}, #{connection.quote(now)})" }.join(", ")
    sql = <<~SQL.squish
      INSERT INTO search_trends (tag, day, count, created_at, updated_at)
      VALUES #{values_sql}
      ON CONFLICT (tag, day)
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

  # Top tags for given day, ordered by count desc then tag asc
  def self.top_for_day(day: Date.current, limit: 100)
    for_day(day).order(count: :desc, tag: :asc).limit(limit)
  end

  def self.rising(day: Date.current, limit: 10, min_today: 10, min_delta: 10, min_ratio: 2.0)
    d = day.to_date
    y = d - 1.day

    joins(<<~SQL.squish)
      LEFT JOIN search_trends y
        ON y.tag = search_trends.tag AND y.day = #{connection.quote(y)}
    SQL
      .where(day: d)
      .where("search_trends.count >= ?", min_today)
      .where(
        "(search_trends.count - COALESCE(y.count, 0) >= ?) OR (COALESCE(y.count, 0) > 0 AND search_trends.count::numeric / NULLIF(y.count, 0) >= ?)",
        min_delta, min_ratio
      )
      .order(count: :desc, tag: :asc)
      .limit(limit)
  end
end
