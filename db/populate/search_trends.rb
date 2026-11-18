# frozen_string_literal: true

module Populate
  # Seeds the search trend tables: daily aggregates for `days` and unprocessed hourly rows for `hours`.
  class SearchTrends < Base
    def call
      populate_daily(days: options.fetch(:days, 0), tags_count: options.fetch(:tags_count, 100))
      populate_hourly(hours: options.fetch(:hours, 0), tags_count: options.fetch(:hourly_tags_count, 50))
    end

    private

    def populate_daily(days:, tags_count:, rising_ratio: 0.25)
      return unless days > 0 && tags_count > 0
      log "* Creating SearchTrend daily records for past #{days} days (#{tags_count} tags)"

      tags = tag_names(tags_count, prefix: "trend_tag")
      return if tags.empty?

      start_day = Date.current - (days - 1)
      rising_count = [(tags.size * rising_ratio).to_i, 1].max.clamp(1, tags.size)
      rising_tags = tags.sample(rising_count)

      tags.each do |tag|
        # Establish a baseline that can be below today's min threshold on some days.
        base = rand(6..25)
        prev = nil

        (start_day..Date.current).each do |day|
          prev = if day == start_day
                   base + rand(0..5)
                 else
                   [prev + rand(-2..3), 1].max # small day-to-day drift
                 end

          if day == Date.current
            if rising_tags.include?(tag)
              # Ensure a substantial rise: satisfy both delta>=10 and/or ratio>=2
              ratio_target = rand(2.0..3.0)
              target = [(prev * ratio_target).to_i, prev + 10 + rand(0..20)].max
              prev = [target, 12].max # also meet today's minimum threshold used by .rising
            else
              prev = (prev + rand(-2..2)).clamp(1, 80) # keep today close to yesterday for non-risers
            end
          end

          st = SearchTrend.find_or_initialize_by(tag: tag, day: day)
          st.count = prev
          st.save!
        end
      end

      log "  Created #{tags.size} tags across #{days} days:"
      log "    #{rising_tags.size} rising today"
      log "    #{SearchTrend.count} daily aggregate records"
    end

    def populate_hourly(hours:, tags_count:)
      return unless hours > 0 && tags_count > 0
      log "* Creating SearchTrendHourly records for past #{hours} hours (#{tags_count} tags)"

      tags = tag_names(tags_count, prefix: "hourly_tag", extra: %w[alpha beta])
      return if tags.empty?

      now = Time.current.utc
      start_hour = now.beginning_of_hour - (hours - 1).hours

      tags.each do |tag|
        base_per_hour = rand(1..100)

        hours.times do |i|
          hour_time = start_hour + i.hours
          next if hour_time > now # Don't create future records

          st = SearchTrendHourly.find_or_initialize_by(tag: tag, hour: hour_time)
          st.count = [base_per_hour + rand(-10..10), 1].max
          st.processed = false
          st.save!
        end
      end

      log "  Created #{tags.size} tags across #{hours} hours:"
      log "    #{SearchTrendHourly.count} total hourly records"
      log "    #{SearchTrendHourly.unprocessed.count} unprocessed hourly records"
    end

    # Prefer existing tags; if not enough exist, synthesize the remainder.
    def tag_names(tags_count, prefix:, extra: [])
      tags = Tag.order("random()").limit(tags_count).pluck(:name)
      if tags.size < tags_count
        tags += (1..(tags_count - tags.size)).map { |i| "#{prefix}_#{format('%03d', i)}" }
      else
        tags += extra
      end
      tags.map { |t| t.to_s.downcase.strip }.uniq
    end
  end
end
