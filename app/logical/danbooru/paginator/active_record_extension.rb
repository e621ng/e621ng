require 'active_support/concern'

module Danbooru
  module Paginator
    module ActiveRecordExtension
      extend ActiveSupport::Concern

      module ClassMethods
        include BaseExtension

        def paginate(page, options = {})
          paginated, _mode = paginate_base(page, options)
          paginated
        end

        def paginate_sequential_before(before_id = nil)
          c = limit(records_per_page + 1)

          if before_id.to_i > 0
            c = c.where("#{table_name}.id < ?", before_id.to_i)
          end

          c = c.reorder("#{table_name}.id desc")
          c = c.extending(SequentialCollectionExtension)
          c.sequential_paginator_mode = :before
          c
        end

        def paginate_sequential_after(after_id)
          c = limit(records_per_page + 1).where("#{table_name}.id > ?", after_id.to_i).reorder("#{table_name}.id asc")
          c = c.extending(SequentialCollectionExtension)
          c.sequential_paginator_mode = :after
          c
        end

        def paginate_numbered(page)
          extending(NumberedCollectionExtension).limit(records_per_page).offset((page - 1) * records_per_page).tap do |obj|
            if records_per_page > 0
              obj.total_pages = (obj.total_count.to_f / records_per_page).ceil
            else
              obj.total_pages = 1
            end
            obj.current_page = page
          end
        end

        # taken from kaminari (https://github.com/amatsuda/kaminari)
        def total_count
          return optimized_count if optimized_count

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
end
