require 'active_support/core_ext/module'
module Danbooru
  module Paginator
    class PaginatedArray < Array
      attr_internal_accessor :records_per_page, :total_count, :sequential_paginator_mode, :current_page, :orig_size

      def initialize(orig_array, options = {})
        @_current_page = options[:current_page]
        @_records_per_page = options[:per_page]
        @_total_count = options[:total]
        @_max_numbered_pages = options[:max_numbered_pages] || Danbooru.config.max_numbered_pages
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

      def max_numbered_pages
        @_max_numbered_pages
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
      include BaseExtension

      attr_reader :current_page, :sequential_paginator_mode

      def paginate(page, options)
        paginated, mode = paginate_base(page, options)

        new_opts = {mode: mode, seq_mode: sequential_paginator_mode, max_numbered_pages: max_numbered_pages,
                    per_page: records_per_page, total: total_count, current_page: current_page}
        if options[:results] == :results
          PaginatedArray.new(paginated.results, new_opts)
        else
          PaginatedArray.new(paginated.records(includes: options[:includes]).to_a, new_opts)
        end
      end

      def paginate_sequential_before(before_id = nil)
        search.definition.update(size: records_per_page + 1, track_total_hits: records_per_page+1)
        search.definition[:body].update(sort: [{id: :desc}])

        if before_id.to_i > 0
          query_definition[:bool][:must].push({range: {id: {lt: before_id.to_i}}})
        end

        @sequential_paginator_mode = :before

        self
      end

      def paginate_sequential_after(after_id)
        search.definition.update(size: records_per_page + 1, track_total_hits: records_per_page+1)
        search.definition[:body].update(sort: [{id: :asc}])
        query_definition[:bool][:must].push({range: {id: {gt: after_id.to_i}}})
        @sequential_paginator_mode = :after

        self
      end

      def query_definition
        search.definition.dig(:body, :query, :function_score, :query) || search.definition.dig(:body, :query)
      end

      def paginate_numbered(page)
        search.definition.update(size: records_per_page, from: (page - 1) * records_per_page, track_total_hits: (max_numbered_pages * records_per_page) + 1)
        @current_page = page

        self
      end

      def limit(count)
        search.definition.update(size: count)
        self
      end

      def real_count
        if response['hits']['total'].respond_to?(:keys)
          response['hits']['total']['value']
        else
          response['hits']['total']
        end
      end

      def exists?
        search.definition[:body]&.delete(:sort)
        search.definition.update(from: 0, size: 1, terminate_after: 1, sort: '_doc', _source: false, track_total_hits: false)
        real_count > 0
      end

      def count_only
        search.definition[:body]&.delete(:sort)
        search.definition.update(from: 0, size: 0, sort: '_doc', _source: false, track_total_hits: true)
        real_count
      end
    end
  end
end
