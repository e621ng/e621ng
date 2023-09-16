module Danbooru
  module Paginator
    class PaginatedArray < Array
      attr_reader :pagination_mode, :max_numbered_pages, :orig_size, :current_page, :records_per_page, :total_count

      def initialize(orig_array, options = {})
        @current_page = options[:current_page]
        @records_per_page = options[:records_per_page]
        @total_count = options[:total_count]
        @max_numbered_pages = options[:max_numbered_pages] || Danbooru.config.max_numbered_pages
        @pagination_mode = options[:pagination_mode]
        real_array = orig_array || []
        @orig_size = real_array.size

        case @pagination_mode
        when :sequential_before, :sequential_after
          real_array = orig_array.first(records_per_page)

          if @pagination_mode == :sequential_before
            super(real_array)
          else
            super(real_array.reverse)
          end
        when :numbered
          super(real_array)
        end
      end

      def is_first_page?
        case @pagination_mode
        when :numbered
          current_page == 1
        when :sequential_before
          false
        when :sequential_after
          orig_size <= records_per_page
        end
      end

      def is_last_page?
        case @pagination_mode
        when :numbered
          current_page >= total_pages
        when :sequential_before
          orig_size <= records_per_page
        when :sequential_after
          false
        end
      end

      def total_pages
        if records_per_page > 0
          (total_count.to_f / records_per_page).ceil
        else
          1
        end
      end
    end
  end
end
