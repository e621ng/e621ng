module DocumentStore
  module Model
    def self.included(klass)
      klass.extend(ClassMethods)

      klass.document_store_index_name = "#{klass.model_name.plural}_#{Rails.env}"

      klass.after_commit on: %i[create update] do
        update_index
      end

      klass.after_commit on: [:destroy] do
        document_store_delete_document(refresh: Rails.env.test?.to_s)
      end
    end

    def update_index(queue: :high_prio)
      # TODO: race condition hack, makes tests SLOW!!!
      return document_store_update_index refresh: "true" if Rails.env.test?

      IndexUpdateJob.set(queue: queue).perform_later(self.class.to_s, id)
    end

    def document_store_update_index(refresh: "false")
      document_store_client.index(index: document_store_index_name, id: id, body: as_indexed_json, refresh: refresh)
    end

    def document_store_delete_document(refresh: "false")
      document_store_client.delete(index: document_store_index_name, id: id, refresh: refresh)
    end

    def document_store_index_name
      self.class.document_store_index_name
    end

    def document_store_client
      DocumentStore.client
    end

    module ClassMethods
      attr_accessor :document_store_index, :document_store_index_name

      def document_store_search(body)
        search = SearchRequest.new({ index: document_store_index_name, body: body }, document_store_client)
        Response.new(self, search)
      end

      def document_store_create_index!(delete_existing: false)
        exists = document_store_index_exist?
        return if exists && !delete_existing

        document_store_delete_index! if exists && delete_existing

        document_store_client.indices.create(index: document_store_index_name, body: document_store_index)
      end

      def document_store_delete_index!
        document_store_client.indices.delete(index: document_store_index_name, ignore: 404)
      end

      def document_store_index_exist?
        document_store_client.indices.exists(index: document_store_index_name)
      end

      def document_store_refresh_index!
        document_store_client.indices.refresh(index: document_store_index_name)
      end

      def document_store_delete_by_query(query:, body:)
        document_store_client.delete_by_query(index: document_store_index_name, q: query, body: body)
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
