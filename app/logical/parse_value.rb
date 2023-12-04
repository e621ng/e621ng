module ParseValue
  extend self

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

  def range_fudged(range, type)
    result = range(range, type)
    if result[0] == :eq
      new_min = [(result[1] * 0.95).to_i, -2_147_483_648].max
      new_max = [(result[1] * 1.05).to_i, 2_147_483_647].min
      [:between, new_min, new_max]
    else
      result
    end
  end

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
      object.to_i

    when :float
      object.to_f

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
        Time.zone.parse(object)
      rescue ArgumentError
        nil
      end

    when :age
      time_string(object)

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

  def yester_range(count, unit)
    origin = Date.current - count.send(unit)
    start = origin.send("beginning_of_#{unit}")
    stop = origin.send("end_of_#{unit}")
    [:between, start, stop]
  end

  def time_string(target)
    target =~ /\A(\d+)_?(s(econds?)?|mi(nutes?)?|h(ours?)?|d(ays?)?|w(eeks?)?|mo(nths?)?|y(ears?)?)_?(ago)?\z/i

    size = $1.to_i
    unit = $2&.downcase || ""

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
