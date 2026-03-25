# frozen_string_literal: true

module SearchTrendsHelper
  def rising_tags
    rising_tags = SearchTrendHourly.rising_tags_list

    return "" if rising_tags.blank?

    tag.ul(class: "rising-tags") do
      html = "".html_safe
      half = (rising_tags.size / 2.0).ceil
      left_tags, right_tags = rising_tags.each_slice(half).to_a

      [left_tags, right_tags].each do |group|
        next if group.blank?
        html << tag.ul do
          group.inject("".html_safe) do |acc, t|
            acc << tag.li { link_to t, posts_path(tags: t) }
          end
        end
      end

      html
    end
  end
end
