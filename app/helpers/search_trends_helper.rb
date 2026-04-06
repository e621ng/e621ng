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

    # New system:
    # First tag - gets wiki excerpt, is larger
    first_tag = categorized_tags.shift

    # Next 2 tags - medium size, no wiki
    if categorized_tags.size >= 2
      medium_tags = categorized_tags.shift(2)
    else
      medium_tags = categorized_tags.shift(categorized_tags.size)
    end
    # Rest of the tags - small size, no wiki
    small_tags = categorized_tags

    render partial: "search_trends/rising_inline", locals: { first_tag: first_tag, medium_tags: medium_tags, small_tags: small_tags }

    # tag.ul(class: "rising-tags") do
    #   html = "".html_safe
    #   half = (rising_tags.size / 2.0).ceil
    #   left_tags, right_tags = rising_tags.each_slice(half).to_a
    #
    #   [left_tags, right_tags].each do |group|
    #     next if group.blank?
    #     html << tag.ul do
    #       group.inject("".html_safe) do |acc, t|
    #         acc << tag.li { link_to t, posts_path(tags: t) }
    #       end
    #     end
    #   end
    #
    #   html
    # end
  end
end
