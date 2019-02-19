module Danbooru
  module Paginator
    module ElasticsearchExtensions
      attr_reader :records_per_page, :total_entries

      module SequentialPaginator
        attr_reader :sequential_paginator_mode

        def is_first_page?
          if sequential_paginator_mode == :before
            false
          else
            size <= records_per_page
          end
        end

        def is_last_page?
          if sequential_paginator_mode == :after
            false
          else
            size <= records_per_page
          end
        end

        # TODO: Some shim here for this that works along side the elasticsearch-models record system.
        # XXX Hack: in sequential pagination we fetch one more record than we need
        # so that we can tell when we're on the first or last page. Here we override
        # a rails internal method to discard that extra record. See #2044, #3642.
        # def records
        #   if sequential_paginator_mode == :before
        #     super.first(records_per_page)
        #   else
        #     super.first(records_per_page).reverse
        #   end
        # end
      end

      module NumberedPaginator
        attr_reader :current_page

        def is_first_page?
          current_page == 1
        end

        def is_last_page?
          current_page >= total_pages
        end

        def total_pages
          if records_per_page > 0
            (total_count.to_f / records_per_page).ceil
          else
            1
          end
        end
      end

      def self.included(base)
        methods = [:current_page, :records_per_page, :total_pages, :total_count, :is_first_page?, :is_last_page?]
        Elasticsearch::Model::Response::Results.__send__ :delegate, *methods, to: :response
        Elasticsearch::Model::Response::Records.__send__ :delegate, *methods, to: :response
      end

      def paginate(page, options = {})
        Rails.logger.warn("[PAGINATE] Paginate #{page} #{options.inspect} #{search.definition.inspect}")
        @paginator_options = options

        if use_sequential_paginator?(page)
          paginate_sequential(page)
        else
          paginate_numbered(page)
        end
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

      def paginate_sequential_before(before_id = nil)
        search.definition.update(size: records_per_page + 1, sort: [{id: :desc}])


        if before_id.to_i > 0
          search.definition[:body][:query][:bool][:must] << ({range: {id: {lt: before_id.to_i}}})
        end

        extend(SequentialPaginator)
        @sequential_paaginator_mode = :before

        self
      end

      def paginate_sequential_after(after_id)
        search.definition.update(size: records_per_page + 1, sort: [{id: :asc}])
        search.definition[:body][:query][:bool][:must] << ({range: {id: {gt: after_id.to_i}}})
        extend(SequentialPaginator)
        @sequential_paginator_mode = :after

        self
      end

      def paginate_numbered(page)
        page = [page.to_i, 1].max

        if page > Danbooru.config.max_numbered_pages
          raise ::Danbooru::Paginator::PaginationError.new("You cannot go beyond page #{Danbooru.config.max_numbered_pages}. Please narrow your search terms.")
        end

        extend(NumberedPaginator)
        search.definition.update(size: records_per_page, from: (page - 1) * records_per_page)
        @current_page = page

        self
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
          if limit.to_i > 1_000
            limit = 1_000
          end
          limit

        when :count
          if @paginator_options.has_key?(:search_count) && @paginator_options[:search_count].blank?
            1_000_000
          elsif @paginator_options[:count]
            @paginator_options[:count]
          else
            nil
          end
        end
      end

      def total_count
        return option_for(:count) if option_for(:count)

        results.total
      end
    end
  end
end