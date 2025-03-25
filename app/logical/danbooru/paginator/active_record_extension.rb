# frozen_string_literal: true

module Danbooru
  module Paginator
    module ActiveRecordExtension
      include BaseExtension

      def paginate_numbered
        limit(records_per_page).offset((current_page - 1) * records_per_page)
      end

      def paginate_sequential_before
        q = limit(records_per_page + 1)
        q = q.where("#{table_name}.id < ?", current_page)
        q.reorder("#{table_name}.id desc")
      end

      def paginate_sequential_after
        q = limit(records_per_page + 1)
        q = q.where("#{table_name}.id > ?", current_page)
        q.reorder("#{table_name}.id asc")
      end

      def is_first_page?
        case @pagination_mode
        when :numbered
          current_page == 1
        when :sequential_before
          false
        when :sequential_after
          load
          @records.size <= records_per_page
        end
      end

      def is_last_page?
        case @pagination_mode
        when :numbered
          current_page >= total_pages
        when :sequential_before
          load
          @records.size <= records_per_page
        when :sequential_after
          false
        end
      end

      # XXX Hack: in sequential pagination we fetch one more record than we need
      # so that we can tell when we're on the first or last page. Here we override
      # a rails internal method to discard that extra record. See #2044, #3642.
      def records
        case @pagination_mode
        when :numbered
          super
        when :sequential_before
          super.first(records_per_page)
        when :sequential_after
          super.first(records_per_page).reverse
        end
      end

      # taken from kaminari (https://github.com/amatsuda/kaminari)
      def real_count
        c = except(:offset, :limit, :order)
        c = c.reorder(nil)
        c = c.count
        c.respond_to?(:count) ? c.count : c
      rescue ActiveRecord::StatementInvalid => e
        if e.to_s =~ /statement timeout/
          1_000_000
        else
          raise
        end
      end
    end
  end
end
