# frozen_string_literal: true

module PostSetPresenters
  class Popular < Base
    delegate :posts, :date, :min_date, :max_date, to: :post_set
    attr_accessor :post_set

    def initialize(post_set)
      super()
      @post_set = post_set
    end

    def prev_day
      date - 1.day
    end

    def next_day
      date + 1.day
    end

    def prev_week
      date - 7.days
    end

    def next_week
      date + 7.days
    end

    def prev_month
      1.month.ago(date)
    end

    def next_month
      1.month.since(date)
    end

    def link_rel_for_scale?(template, scale)
      (template.params[:scale].blank? && scale == "day") || template.params[:scale].to_s.include?(scale)
    end

    def next_date_for_scale(scale)
      case scale
      when "day"
        next_day
      when "week"
        next_week
      when "month"
        next_month
      end
    end

    def prev_date_for_scale(scale)
      case scale
      when "day"
        prev_day
      when "week"
        prev_week
      when "month"
        prev_month
      end
    end

    def nav_links_for_scale(template, scale)
      template.tag.span(class: "period") do
        prev_link = template.link_to(
          "«prev",
          template.popular_index_path(
            date: prev_date_for_scale(scale),
            scale: scale,
          ),
          id: link_rel_for_scale?(template, scale) ? "paginator-prev" : nil,
          rel: link_rel_for_scale?(template, scale) ? "prev" : nil,
          data: { hotkey: link_rel_for_scale?(template, scale) ? "prev" : nil },
        )
        scale_link = template.link_to(scale.capitalize, template.popular_index_path(date: date, scale: scale), class: "desc")
        next_link = template.link_to(
          "next»",
          template.popular_index_path(
            date: next_date_for_scale(scale),
            scale: scale,
          ),
          id: link_rel_for_scale?(template, scale) ? "paginator-next" : nil,
          rel: link_rel_for_scale?(template, scale) ? "next" : nil,
          data: { hotkey: link_rel_for_scale?(template, scale) ? "next" : nil },
        )
        prev_link + scale_link + next_link
      end
    end

    def nav_links(template)
      template.tag.p(id: "popular-nav-links") do
        template.safe_join(%w[day week month].map { |scale| nav_links_for_scale(template, scale) }, " ")
      end
    end

    def range_text
      if min_date == max_date
        date.strftime("%B %d, %Y")
      elsif max_date - min_date < 10.days
        min_date.strftime("Week of %B %d, %Y")
      else
        date.strftime("%B %Y")
      end
    end
  end
end
