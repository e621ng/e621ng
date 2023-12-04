module Danbooru
  module Paginator
    module DocumentStoreExtensions
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

        PaginatedArray.new(records(includes: options[:includes]), new_opts)
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
