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

    module ElasticsearchExtensions
      include BaseExtension

      def paginate(page, options)
        super(page, options)

        new_opts = {
          pagination_mode: pagination_mode,
          max_numbered_pages: max_numbered_pages,
          records_per_page: records_per_page,
          total_count: total_count,
          current_page: current_page,
        }

        PaginatedArray.new(records(includes: options[:includes]).to_a, new_opts)
      end

      def paginate_numbered
        search.definition.update(size: records_per_page, from: (current_page - 1) * records_per_page, track_total_hits: (max_numbered_pages * records_per_page) + 1)
      end

      def paginate_sequential_before
        search.definition.update(size: records_per_page + 1, track_total_hits: records_per_page + 1)
        search.definition[:body].update(sort: [{ id: :desc }])
        query_definition[:bool][:must].push({ range: { id: { lt: current_page } } })
      end

      def paginate_sequential_after
        search.definition.update(size: records_per_page + 1, track_total_hits: records_per_page + 1)
        search.definition[:body].update(sort: [{ id: :asc }])
        query_definition[:bool][:must].push({ range: { id: { gt: current_page } } })
      end

      def query_definition
        search.definition.dig(:body, :query, :function_score, :query) || search.definition.dig(:body, :query)
      end

      def limit(count)
        search.definition.update(size: count)
        self
      end

      def real_count
        if response["hits"]["total"].respond_to?(:keys)
          response["hits"]["total"]["value"]
        else
          response["hits"]["total"]
        end
      end

      def exists?
        search.definition[:body]&.delete(:sort)
        search.definition.update(from: 0, size: 1, terminate_after: 1, sort: "_doc", _source: false, track_total_hits: false)
        real_count > 0
      end

      def count_only
        search.definition[:body]&.delete(:sort)
        search.definition.update(from: 0, size: 0, sort: "_doc", _source: false, track_total_hits: true)
        real_count
      end
    end
  end
end
