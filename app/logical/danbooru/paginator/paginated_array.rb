# frozen_string_literal: true

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
        @sequential_first_id = options[:sequential_first_id]
        @sequential_last_id = options[:sequential_last_id]
        @is_first_page = options[:is_first_page]
        @is_last_page = options[:is_last_page]
        real_array = orig_array || []
        @orig_size = real_array.size

        if options[:finalized]
          super(real_array)
          return
        end

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

      def sequential_first_id
        @sequential_first_id || first&.id
      end

      def sequential_last_id
        @sequential_last_id || last&.id
      end

      def is_first_page?
        return @is_first_page unless @is_first_page.nil?
        case @pagination_mode
        when :numbered
          current_page == 1
        when :sequential_before
          empty?
        when :sequential_after
          orig_size <= records_per_page
        end
      end

      def is_last_page?
        return @is_last_page unless @is_last_page.nil?
        case @pagination_mode
        when :numbered
          current_page >= total_pages
        when :sequential_before
          orig_size <= records_per_page
        when :sequential_after
          empty? || last.id <= 1
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
