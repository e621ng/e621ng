# frozen_string_literal: true

module SearchTrendsHelper
  def rising_tags
    rising_tags = SearchTrendHourly.rising_tags_list

    return "" if rising_tags.blank?

    half = (rising_tags.size / 2.0).ceil
    left_tags, right_tags = rising_tags.each_slice(half).to_a

    # Left tags are always present, right tags may be nil
    left_tags.each { |tag| tag[:place] = 2 }
    left_tags.first[:place] = 1
    right_tags.each { |tag| tag[:place] = 3 } if right_tags.present?

    render partial: "search_trends/rising_inline", locals: { left_tags: left_tags, right_tags: right_tags }
  end
end
