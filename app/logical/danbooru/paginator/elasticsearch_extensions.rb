require 'active_support/core_ext/module'
module Danbooru
  module Paginator
    class PaginatedArray < Array
      attr_internal_accessor :records_per_page, :total_count, :sequential_paginator_mode, :current_page, :orig_size

      def initialize(orig_array, options = {})
        @_current_page = options[:current_page]
        @_records_per_page = options[:per_page]
        @_total_count = options[:total]
        real_array = orig_array || []
        @_orig_size = real_array.size
        if options[:mode] == :sequential
          @_sequential_paginator_mode = options[:seq_mode]

          real_array = orig_array.first(records_per_page)

          if @_sequential_paginator_mode == :before
            super(real_array)
          else
            super(real_array.reverse)
          end
        else
          super(real_array)
        end
      end

      def is_first_page?
        if sequential_paginator_mode
          sequential_paginator_mode == :before ? false : orig_size <= records_per_page
        else
          current_page == 1
        end
      end

      def is_last_page?
        if sequential_paginator_mode
          sequential_paginator_mode == :after ? false : orig_size <= records_per_page
        else
          current_page >= total_pages
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

    module ElasticsearchExtensions
      attr_reader :records_per_page, :total_entries, :current_page, :sequential_paginator_mode

      def paginate(page, options = {})
        @paginator_options = options

        validate_page_number(page)
        sequential = use_sequential_paginator?(page)
        paginated = if sequential
                      paginate_sequential(page)
                    else
                      paginate_numbered(page)
                    end

        new_opts = {mode: (sequential ? :sequential : :numbered), seq_mode: sequential_paginator_mode,
                    per_page: records_per_page, total: total_count, current_page: current_page}
        if options[:results] == :results
          PaginatedArray.new(paginated.results, new_opts)
        else
          PaginatedArray.new(paginated.records(includes: options[:includes]).to_a, new_opts)
        end
      end

      def validate_page_number(page)
        return if page.is_a? Numeric
        return if page.blank?
        raise ::Danbooru::Paginator::PaginationError.new("Invalid page number.") unless page =~ /\A[ab]?\d+\z/i
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
        search.definition.update(size: records_per_page + 1, track_total_hits: records_per_page+1)
        search.definition[:body].update(sort: [{id: :desc}])


        if before_id.to_i > 0
          search.definition[:body][:query][:bool][:must] << ({range: {id: {lt: before_id.to_i}}})
        end

        @sequential_paginator_mode = :before

        self
      end

      def paginate_sequential_after(after_id)
        search.definition.update(size: records_per_page + 1, track_total_hits: records_per_page+1)
        search.definition[:body].update(sort: [{id: :asc}])
        search.definition[:body][:query][:bool][:must] << ({range: {id: {gt: after_id.to_i}}})
        @sequential_paginator_mode = :after

        self
      end

      def paginate_numbered(page)
        page = [page.to_i, 1].max

        if page > Danbooru.config.max_numbered_pages
          raise ::Danbooru::Paginator::PaginationError.new("You cannot go beyond page #{Danbooru.config.max_numbered_pages}. Please narrow your search terms.")
        end

        search.definition.update(size: records_per_page, from: (page - 1) * records_per_page, track_total_hits: 750*records_per_page + 1)
        @current_page = page

        self
      end

      def records_per_page
        option_for(:limit).to_i
      end

      def limit(count)
        search.definition.update(size: count)
        self
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

        response_hits_total
      end

      def response_hits_total
        if response['hits']['total'].respond_to?(:keys)
          response['hits']['total']['value']
        else
          response['hits']['total']
        end
      end

      def exists?
        search.definition[:body]&.delete(:sort)
        search.definition.update(from: 0, size: 1, terminate_after: 1, sort: '_doc', _source: false, track_total_hits: false)
        response_hits_total > 0
      end

      def count_only
        search.definition[:body]&.delete(:sort)
        search.definition.update(from: 0, size: 0, sort: '_doc', _source: false, track_total_hits: true)
        response_hits_total
      end
    end
  end
end
