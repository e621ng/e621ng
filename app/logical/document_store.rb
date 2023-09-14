module DocumentStore
  module Model
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def document_store_create_index!(delete_existing: false)
        exists = document_store_index_exist?
        return if exists && !delete_existing

        document_store_delete_index! if exists && delete_existing

        document_store_client.indices.create(index: __elasticsearch__.index_name, body: {
          settings: __elasticsearch__.settings.to_hash,
          mappings: __elasticsearch__.mappings.to_hash,
        })
      end

      def document_store_delete_index!
        document_store_client.indices.delete(index: __elasticsearch__.index_name, ignore: 404)
      end

      def document_store_index_exist?
        document_store_client.indices.exists(index: __elasticsearch__.index_name)
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
