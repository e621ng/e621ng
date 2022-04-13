module Danbooru
  module Paginator
    module BaseExtension
      def paginate_base(page, options)
        @paginator_options = options

        validate_page_number(page)
        if use_sequential_paginator?(page)
          [paginate_sequential(page), :sequential]
        else
          [paginate_numbered(page), :numbered]
        end
      end

      def validate_page_number(page)
        return if page.is_a? Numeric
        return if page.blank?
        raise Danbooru::Paginator::PaginationError, "Invalid page number." unless page =~ /\A[ab]?\d+\z/i
      end

      def validate_numbered_page(page)
        page = [page.to_i, 1].max
        if page > Danbooru.config.max_numbered_pages
          raise Danbooru::Paginator::PaginationError, "You cannot go beyond page #{Danbooru.config.max_numbered_pages}. Please narrow your search terms."
        end
        page
      end

      def use_sequential_paginator?(page)
        page =~ /[ab]\d+/i
      end

      def paginate_sequential(page)
        if page =~ /b(\d+)/
          paginate_sequential_before($1)
        elsif page =~ /a(\d+)/
          paginate_sequential_after($1)
        else
          paginate_sequential_before
        end
      end

      def records_per_page
        option_for(:limit).to_i
      end

      # When paginating large tables, we want to avoid doing an expensive count query
      # when the result won't even be used. So when calling paginate you can pass in
      # an optional :search_count key which points to the search params. If these params
      # exist, then assume we're doing a search and don't override the default count
      # behavior. Otherwise, just return some large number so the paginator skips the
      # count.
      def option_for(key)
        case key
        when :limit
          limit = @paginator_options.try(:[], :limit) || Danbooru.config.posts_per_page
          if limit.to_i > 320
            limit = 320
          end
          limit

        when :count
          if @paginator_options.key?(:search_count) && @paginator_options[:search_count].blank?
            1_000_000
          elsif @paginator_options[:count]
            @paginator_options[:count]
          else
            nil
          end
        end
      end
    end
  end
end
