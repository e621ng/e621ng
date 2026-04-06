# frozen_string_literal: true

module SearchTrendsHelper
  def rising_tags
    rising_tags = SearchTrendHourly.rising_tags_list

    return "" if rising_tags.blank?

    tag_data = Tag.where(name: rising_tags).index_by(&:name)
    categorized_tags = rising_tags.map do |tag|
      {
        name: tag,
        pretty_name: tag.gsub(/_+/, " "),
        post_count: tag_data[tag]&.post_count || 0,
        category: tag_data[tag]&.category || 0,
      }
    end

    half = (categorized_tags.size / 2.0).ceil
    left_tags, right_tags = categorized_tags.each_slice(half).to_a

    left_tags.each { |tag| tag[:place] = 2 }
    left_tags.first[:place] = 1
    right_tags.each { |tag| tag[:place] = 3 }

    render partial: "search_trends/rising_inline", locals: { left_tags: left_tags, right_tags: right_tags }
  end
end
