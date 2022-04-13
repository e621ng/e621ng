module Danbooru
  module Paginator
    module BaseExtension
      def paginate_base(page, options)
        @paginator_options = options

        if use_numbered_paginator?(page)
          [paginate_numbered(page), :numbered]
        elsif use_sequential_paginator?(page)
          [paginate_sequential(page), :sequential]
        else
          raise Danbooru::Paginator::PaginationError, "Invalid page number."
        end
      end

      def validate_numbered_page(page)
        page = [page.to_i, 1].max
        if page > Danbooru.config.max_numbered_pages
          raise Danbooru::Paginator::PaginationError, "You cannot go beyond page #{Danbooru.config.max_numbered_pages}. Please narrow your search terms."
        end
        page
      end

      def use_numbered_paginator?(page)
        page.blank? || page.to_s =~ /\A\d+\z/
      end

      def use_sequential_paginator?(page)
        page =~ /\A[ab]\d+\z/i
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
