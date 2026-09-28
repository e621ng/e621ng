# frozen_string_literal: true

module Danbooru
  module Paginator
    class PaginatedArray < Array
      attr_reader :pagination_mode, :max_numbered_pages, :orig_size, :current_page, :records_per_page, :total_count, :real_total_count

      def initialize(orig_array, options = {})
        @current_page = options[:current_page]
        @records_per_page = options[:records_per_page]
        @total_count = options[:total_count]
        # Optional: the true, uncapped row count, when total_count above has been capped
        # for pagination-metadata purposes (see PostSets::Favorites#capped_total_count).
        # nil for every caller that doesn't pass it, which is every PostSet except a
        # folder-scoped one - total_count and is_last_page?/total_pages (all pagination
        # math/links) are entirely unaffected by this option; it exists purely so display
        # code (see PaginationHelper#approximate_count) can show the real count without
        # an extra query of its own.
        @real_total_count = options[:real_total_count]
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
          empty?
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

      # True only when real_total_count was actually supplied AND is larger than the
      # (possibly capped) total_count pagination itself is using - i.e. there really is
      # more data than the numbered-page ceiling can ever reach. False for every PostSet
      # that never passes real_total_count, and false for a folder small enough that no
      # capping ever occurred, even though real_total_count was still supplied there.
      def capped?
        !real_total_count.nil? && real_total_count > total_count
      end
    end
  end
end
