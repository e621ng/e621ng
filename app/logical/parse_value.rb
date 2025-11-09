# frozen_string_literal: true

module ParseValue
  MAX_INT = 2_147_483_647
  MIN_INT = -2_147_483_648
  extend self

  # Parses the specified time
  def date_from(target)
    case target
    # 10_yesterweeks_ago, 10yesterweekago
    when /\A(\d{1,2})_?yester(week|month|year)s?_?ago\z/
      yester_unit($1.to_i, $2)
    when /\Ayester(week|month|year)\z/
      yester_unit(1, $1)
    when /\A(day|week|month|year)\z/
      Time.zone.now - 1.send($1)
    # 10_weeks_ago, 10w
    when /\A(\d+)_?(s(econds?)?|mi(nutes?)?|h(ours?)?|d(ays?)?|w(eeks?)?|mo(nths?)?|y(ears?)?)_?(ago)?\z/i
      time_string(target)
    else
      cast(target, :date)
    end
  end

  def date_range(target)
    case target
    # 10_yesterweeks_ago, 10yesterweekago
    when /\A(\d{1,2})_?yester(week|month|year)s?_?ago\z/
      yester_range($1.to_i, $2)
    when /\Ayester(week|month|year)\z/
      yester_range(1, $1)
    when /\A(day|week|month|year)\z/
      [:gte, Time.zone.now - 1.send($1)]
    # 10_weeks_ago, 10w
    when /\A(\d+)_?(s(econds?)?|mi(nutes?)?|h(ours?)?|d(ays?)?|w(eeks?)?|mo(nths?)?|y(ears?)?)_?(ago)?\z/i
      [:gte, time_string(target)]
    else
      range(target, :date)
    end
  end

  # Same as `ParseValue#range`, except when `range` uses no comparisons, it is converted to a range of the value +/- 5%.
  # Used for `filesize` & `mpixels`.
  #
  # IDEA: Only cast to integer if `type` is `filesize`, so both fudged & non-fudged `mpixels` are floating point.
  #
  # IDEA: enforce only positive integers
  def range_fudged(range, type)
    result = range(range, type)
    if result[0] == :eq
      new_min = [(result[1] * 0.95).to_i, MIN_INT].max
      new_max = [(result[1] * 1.05).to_i, MAX_INT].min
      [:between, new_min, new_max]
    else
      result
    end
  end

  # ### Parameters
  # * `range`
  # * `type` [`:integer`]
  # ### Returns
  # An array where the 1st element is the comparison operator and the remaining elements are the
  # data to compare to. The operators are:
  # * `:lte`
  # * `:lt`
  # * `:gte`
  # * `:gt`
  # * `:between`
  # * `:in`
  # * `:eq`
  def range(range, type = :integer)
    if range.start_with?("<=")
      [:lte, cast(range.delete_prefix("<="), type)]

    elsif range.start_with?("..")
      [:lte, cast(range.delete_prefix(".."), type)]

    elsif range.start_with?("<")
      [:lt, cast(range.delete_prefix("<"), type)]

    elsif range.start_with?(">=")
      [:gte, cast(range.delete_prefix(">="), type)]

    elsif range.end_with?("..")
      [:gte, cast(range.delete_suffix(".."), type)]

    elsif range.start_with?(">")
      [:gt, cast(range.delete_prefix(">"), type)]

    elsif range.include?("..")
      left, right = range.split("..", 2)
      [:between, cast(left, type), cast(right, type)]

    elsif range.include?(",")
      [:in, range.split(",")[0..99].map { |x| cast(x, type) }]

    else
      [:eq, cast(range, type)]

    end
  end

  RANGE_INVERSIONS = {
    lte: :gte,
    lt: :gt,
    gte: :lte,
    gt: :lt,
  }.freeze

  def invert_range(range)
    # >10 <=> <10
    range[0] = RANGE_INVERSIONS[range[0]] || range[0]
    # 10..20 <=> 20..10
    range[1], range[2] = range[2], range[1] if range[0] == :between
    range
  end

  private

  def cast(object, type)
    case type
    when :integer
      object.to_i.clamp(MIN_INT, MAX_INT)

    when :float
      # Floats obviously have a different range but this is good enough
      object.to_f.clamp(MIN_INT, MAX_INT)

    when :date, :datetime
      case object
      when "today"
        return Date.current
      when "yesterday"
        return Date.yesterday
      when "decade"
        return Date.current - 10.years
      when /\A(day|week|month|year)\z/
        return Date.current - 1.send($1.to_sym)
      end

      ago = time_string(object)
      return ago if ago.present?

      begin
        parsed_date = Time.zone.parse(object)

        # OpenSearch's strict_date_optional_time format only supports years 0-9999
        return nil if parsed_date && (parsed_date.year < 0 || parsed_date.year > 9999)
        parsed_date
      rescue ArgumentError
        nil
      end

    when :age
      if object
        time_string(object) || object.to_s[/\A\d+\z/]&.to_i&.clamp(MIN_INT, MAX_INT)
      else
        object
      end

    when :ratio
      left, right = object.split(":", 2)

      if right && right.to_f != 0.0
        (left.to_f / right.to_f).round(2)
      elsif right
        0.0
      else
        object.to_f.round(2)
      end

    when :filesize
      size = object.downcase
      if size.end_with?("kb")
        size.to_f.kilobytes
      elsif size.end_with?("mb")
        size.to_f.megabytes
      else
        size.to_f
      end.to_i
    end
  end

  def yester_unit(count, unit)
    Date.current - count.send(unit)
  end

  def yester_range(count, unit)
    origin = yester_unit(count, unit)
    start = origin.send("beginning_of_#{unit}")
    stop = origin.send("end_of_#{unit}")
    [:between, start, stop]
  end

  # A symbol denoting the interval method used in `time_string` when the input doesn't contain one.
  DEFAULT_TIME_UNIT = :days

  # If no unit can be found, will default to `DEFAULT_TIME_UNIT`.
  # If this behavior is changed, update the corresponding test in `test/unit/post_test.rb`
  # (context "Searching:", should "return posts for the age:<n> metatag", 1st assertion gives no
  # time unit).
  #
  # If no size can be found, returns nil.
  def time_string(target)
    match = /\A(\d+)(?>_?(s(>?econds?)?|mi(>?nutes?)?|h(>?ours?)?|d(>?ays?)?|w(>?eeks?)?|mo(>?nths?)?|y(>?ears?)?)(?>_?ago)?)?\z/i.match(target)

    return nil unless match

    size = match[1].to_i.clamp(MIN_INT, MAX_INT)
    unit = match[2]&.downcase

    return size.send(DEFAULT_TIME_UNIT).ago if unit.blank?

    if unit.start_with?("s")
      size.seconds.ago
    elsif unit.start_with?("mi")
      size.minutes.ago
    elsif unit.start_with?("h")
      size.hours.ago
    elsif unit.start_with?("d")
      size.days.ago
    elsif unit.start_with?("w")
      size.weeks.ago
    elsif unit.start_with?("mo")
      size.months.ago
    elsif unit.start_with?("y")
      size.years.ago
    end
  end
end
