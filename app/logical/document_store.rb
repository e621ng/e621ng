module DocumentStore
  module Model
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    def document_store_update_index(refresh: "false")
      document_store_client.index(index: __elasticsearch__.index_name, id: id, body: as_indexed_json, refresh: refresh)
    end

    def document_store_delete_document(refresh: "false")
      document_store_client.delete(index: __elasticsearch__.index_name, id: id, refresh: refresh)
    end

    def document_store_client
      DocumentStore.client
    end

    module ClassMethods
      attr_accessor :document_store_index

      class SearchRequest
        attr_reader :definition

        def initialize(definition, client)
          @definition = definition
          @client = client
        end

        def execute!
          @client.search(@definition)
        end
      end

      def document_store_search(body)
        search = SearchRequest.new({ index: __elasticsearch__.index_name, body: body }, document_store_client)
        Elasticsearch::Model::Response::Response.new(self, search)
      end

      def document_store_create_index!(delete_existing: false)
        exists = document_store_index_exist?
        return if exists && !delete_existing

        document_store_delete_index! if exists && delete_existing

        document_store_client.indices.create(index: __elasticsearch__.index_name, body: document_store_index)
      end

      def document_store_delete_index!
        document_store_client.indices.delete(index: __elasticsearch__.index_name, ignore: 404)
      end

      def document_store_index_exist?
        document_store_client.indices.exists(index: __elasticsearch__.index_name)
      end

      def document_store_refresh_index!
        document_store_client.indices.refresh(index: __elasticsearch__.index_name)
      end

      def document_store_delete_by_query(query:, body:)
        document_store_client.delete_by_query(index: __elasticsearch__.index_name, q: query, body: body)
      end

      def document_store_client
        DocumentStore.client
      end
    end
  end

  def self.client
    @client ||= Elasticsearch::Client.new(host: Danbooru.config.elasticsearch_host)
  end
end
