# frozen_string_literal: true

module PostSets
  class Popular < PostSets::Base
    attr_reader :date, :scale

    def initialize(date, scale)
      super()
      @date = if date.blank?
                Time.zone.now
              else
                parsed = Time.zone.parse(date)
                raise ArgumentError, "Invalid date: #{date}" if parsed.nil?
                parsed
              end
      @scale = scale
    end

    def posts
      @posts ||= ::Post.where("created_at between ? and ?", min_date.beginning_of_day, max_date.end_of_day).order("score desc").paginate_posts(1)
    end

    def min_date
      case scale
      when "week"
        date.beginning_of_week

      when "month"
        date.beginning_of_month

      else
        date
      end
    end

    def max_date
      case scale
      when "week"
        date.end_of_week

      when "month"
        date.end_of_month

      else
        date
      end
    end

    def presenter
      ::PostSetPresenters::Popular.new(self)
    end
  end
end
