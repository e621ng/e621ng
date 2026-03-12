# frozen_string_literal: true

module SearchTrendsHelper
  def rising_tags
    return "" unless Setting.trends_enabled?

    rising_tags = Cache.fetch("rising_tags", expires_in: 5.seconds) do
      SearchTrend.rising(min_today: Setting.trends_min_today, min_delta: Setting.trends_min_delta, min_ratio: Setting.trends_min_ratio).pluck(:tag)
    end

    tag.ul(class: "rising-tags") do
      html = "".html_safe
      half = (rising_tags.size / 2.0).ceil
      left_tags, right_tags = rising_tags.each_slice(half).to_a

      [left_tags, right_tags].each do |group|
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
