module StatsHelper
  def del(int, pre=0)
    number_with_precision(int, precision: pre, delimiter: ",")
  end

  def humansize(int, pre=0)
    number_to_human_size(int, precision: pre)
  end

  def pct(int, pre=0)
    number_to_percentage(int, precision: pre)
  end
end
