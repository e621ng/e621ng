# frozen_string_literal: true

module StatsHelper
  def del(number)
    number_with_precision(number, precision: 0, delimiter: ",")
  end
end
