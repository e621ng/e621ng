# frozen_string_literal: true

module SearchTrendsHelper
  def rising_tags
    return "" unless Setting.trends_enabled?

    rising_tags = Cache.fetch("rising_tags", expires_in: 5.seconds) do
      SearchTrend.rising(min_today: Setting.trends_min_today, min_delta: Setting.trends_min_delta, min_ratio: Setting.trends_min_ratio).pluck(:tag)
    end

    tag.ul(class: "rising-tags") do
      html = "".html_safe

      rising_tags.each do |t|
        html << tag.li do
          link_to t, posts_path(tags: t)
        end
      end

      html
    end
  end
end
