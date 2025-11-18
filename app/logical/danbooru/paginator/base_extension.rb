# frozen_string_literal: true

module Danbooru
  module Paginator
    module BaseExtension
      attr_reader :current_page, :pagination_mode

      def paginate(page, options = {})
        @paginator_options = options
        @current_page, @pagination_mode = extract_page_options(page.to_s)

        case @pagination_mode
        when :numbered
          paginate_numbered
        when :sequential_before
          paginate_sequential_before
        when :sequential_after
          paginate_sequential_after
        end
      end

      # Only paginating posts should respect the per_page user setting
      def paginate_posts(page, options = {})
        options[:limit] ||= CurrentUser.user.per_page
        paginate(page, options)
      end

      def total_pages
        if @pagination_mode == :numbered
          if records_per_page > 0
            (total_count.to_f / records_per_page).ceil
          else
            1
          end
        end
      end

      def extract_page_options(page)
        if page.blank?
          [1, :numbered]
        elsif page =~ /\A\d+\z/
          if page.to_i > max_numbered_pages
            raise Danbooru::Paginator::PaginationError, "You cannot go beyond page #{max_numbered_pages}. Please narrow your search terms."
          end
          [[page.to_i, 1].max, :numbered]
        elsif page =~ /b(\d+)/
          id = validate_bigint($1)
          [id, :sequential_before]
        elsif page =~ /a(\d+)/
          id = validate_bigint($1)
          [id, :sequential_after]
        else
          raise Danbooru::Paginator::PaginationError, "Invalid page number."
        end
      end

      def validate_bigint(value)
        int_value = value.to_i
        if int_value > 9_223_372_036_854_775_807 || int_value < 0
          raise Danbooru::Paginator::PaginationError, "Page parameter is out of valid range."
        end
        int_value
      end

      def max_numbered_pages
        if @paginator_options[:max_count]
          [Danbooru.config.max_numbered_pages, @paginator_options[:max_count] / records_per_page].min
        else
          Danbooru.config.max_numbered_pages
        end
      end

      def records_per_page
        limit = @paginator_options.try(:[], :limit) || Danbooru.config.records_per_page
        limit.to_i.clamp(0, 320)
      end

      # When paginating large tables, we want to avoid doing an expensive count query
      # when the result won't even be used. So when calling paginate you can pass in
      # an optional :search_count key which points to the search params. If these params
      # exist, then assume we're doing a search and don't override the default count
      # behavior. Otherwise, just return some large number so the paginator skips the
      # count.
      def total_count
        return 1_000_000 if @paginator_options.key?(:search_count) && @paginator_options[:search_count].blank?
        return @paginator_options[:total_count] if @paginator_options[:total_count]

        real_count
      end
    end
  end
end
