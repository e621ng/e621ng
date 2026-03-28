# frozen_string_literal: true

class SearchTrendHourly < ApplicationRecord
  WINDOW_HOURS = 12.hours

  TrendingTag = Struct.new(:tag, :search_count, :delta)

  validates :tag, presence: true, tag_name: true, on: :create
  validates :tag, length: { in: 1..100 }
  validates :hour, presence: true
  validates :count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :hour, uniqueness: { scope: [:tag] }

  scope :for_day, ->(day) {
    day_date = day.to_date
    where(hour: day_date.all_day)
  }
  scope :for_hour, ->(hour) { where(hour: hour.utc.beginning_of_hour).order(count: :desc, tag: :asc) }
  scope :for_tag, ->(tag) { where(tag: tag.to_s.downcase.strip) }

  scope :unprocessed, -> { where(processed: false) }
  scope :processed, -> { where(processed: true) }
  scope :unprocessed_before, ->(time) { unprocessed.where("hour < ?", time) }

  # Parse a raw tag query string, extract plain affirmative tags, and record them.
  # Tags with a `-` prefix (negated) are excluded entirely; tags with only a `~` prefix
  # have that prefix stripped before recording. Metatags (containing `:`) are ignored.
  # Errors in query parsing are logged and swallowed so the caller is never disrupted.
  def self.record_query!(query, hour: Time.now.utc.beginning_of_hour, ip: nil)
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

    bulk_increment!(tag_tokens.map { |tag| { tag: tag, hour: hour } }, ip: ip) if tag_tokens.present?
  rescue StandardError => e
    Rails.logger.warn("Failed to record search trends for query #{query.inspect}: #{e.class}: #{e.message}")
  end

  # Increment multiple tag-hour combinations efficiently in a single query
  def self.bulk_increment!(data, ip: nil)
    return if data.blank?
    return unless Setting.trends_enabled

    # Rate limiting check for IP (once per bulk operation)
    if ip.present?
      ip_key = "trends:ip:#{ip}"
      return if RateLimiter.check_limit(ip_key, Setting.trends_ip_limit, Setting.trends_ip_window.seconds)
    end

    # Group by tag-hour pairs and sum counts
    grouped = data.group_by { |item| [item[:tag].to_s.downcase.strip, item[:hour].utc.beginning_of_hour] }

    values = []
    now = Time.now.utc
    processed_tags = []

    grouped.each do |(tag, hour_time), items|
      next if tag.blank?
      next unless valid_tag?(tag)
      next if SearchTrendBlacklist.blacklisted?(tag)

      # Rate limiting check for tag
      tag_key = "trends:tag:#{tag}"
      next if RateLimiter.check_limit(tag_key, Setting.trends_tag_limit, Setting.trends_tag_window.seconds)

      count = items.length
      values << "(#{connection.quote(tag)}, #{connection.quote(hour_time)}, #{count}, false, #{connection.quote(now)}, #{connection.quote(now)})"
      processed_tags << tag
    end

    return if values.empty?

    values_sql = values.join(", ")
    sql = <<~SQL.squish
      INSERT INTO search_trend_hourlies (tag, hour, count, processed, created_at, updated_at)
      VALUES #{values_sql}
      ON CONFLICT (tag, hour)
      DO UPDATE SET count = search_trend_hourlies.count + EXCLUDED.count, updated_at = EXCLUDED.updated_at
    SQL
    connection.execute(sql)

    # Increment rate limit counters after successful database operation
    if ip.present?
      ip_key = "trends:ip:#{ip}"
      RateLimiter.hit(ip_key, Setting.trends_ip_window.seconds)
    end

    processed_tags.each do |tag|
      tag_key = "trends:tag:#{tag}"
      RateLimiter.hit(tag_key, Setting.trends_tag_window.seconds)
    end
  end

  # Find tags that are trending upward compared to the previous equivalent time window
  def self.rising(at: Time.now.utc, limit: 10, min_today: 10, min_delta: 10, min_ratio: 2.0)
    # Current time window: last WINDOW_HOURS hours up to 'at'
    current_end = at.utc
    current_start = current_end - WINDOW_HOURS

    # Previous time window: same duration, ending WINDOW_HOURS before current window
    previous_end = current_start
    previous_start = previous_end - WINDOW_HOURS

    # Aggregate counts for current window
    current_counts = where(hour: current_start..current_end)
                     .group(:tag)
                     .sum(:count)

    # Aggregate counts for previous window (use exclusive end to avoid overlap)
    previous_counts = where(hour: previous_start...previous_end)
                      .group(:tag)
                      .sum(:count)

    trending = []
    current_counts.each do |tag, current_count|
      next if current_count < min_today

      previous_count = previous_counts[tag] || 0
      delta = current_count - previous_count
      next if delta < min_delta

      if previous_count > 0
        ratio = current_count.to_f / previous_count
        next if ratio < min_ratio
      end

      trending << { tag: tag, count: current_count, delta: delta }
    end

    # Sort by current count descending, then by tag name
    trending.sort_by { |t| [-t[:count], t[:tag]] }
            .first(limit)
            .map { |t| TrendingTag.new(t[:tag], t[:count], t[:delta]) }
  end

  def self.rising_tags_list
    Cache.fetch("rising_tags", expires_in: 15.minutes) do
      tags = SearchTrendHourly.rising(min_today: Setting.trends_min_today, min_delta: Setting.trends_min_delta, min_ratio: Setting.trends_min_ratio).map(&:tag)
      TagAlias.to_aliased(tags)
    end
  end

  # Delete old processed hourly records to prevent the table from growing unbounded.
  # Called during daily maintenance so the hourly buffer stays bounded.
  def self.prune!
    cutoff = Time.now.utc - 48.hours
    processed
      .where("hour < ?", cutoff)
      .in_batches(load: false)
      .delete_all
  end

  def self.search(params)
    q = super

    if params[:name_matches].present?
      q = q.where_ilike(:tag, Tag.normalize_name(params[:name_matches]))
    end

    q
  end

  private

  private_class_method def self.valid_tag?(tag)
    return false unless tag.length.between?(1, 100)
    record = new(tag: tag, hour: Time.now.utc)
    TagNameValidator.new(attributes: [:tag]).validate_each(record, :tag, tag)
    record.errors[:tag].empty?
  end
end
