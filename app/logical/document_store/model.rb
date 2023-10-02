module DocumentStore
  module Model
    def self.included(klass)
      klass.include(Proxy)

      klass.document_store.index_name = "#{klass.model_name.plural}_#{Rails.env}"

      klass.after_commit on: [:create] do
        document_store.update_index(refresh: Rails.env.test?.to_s)
      end

      klass.after_commit on: [:update] do
        update_index
      end

      klass.after_commit on: [:destroy] do
        document_store.delete_document(refresh: Rails.env.test?.to_s)
      end
    end

    def update_index(queue: :high_prio)
      # TODO: race condition hack, makes tests SLOW!!!
      return document_store.update_index refresh: "true" if Rails.env.test?

      IndexUpdateJob.set(queue: queue).perform_later(self.class.to_s, id)
    end
  end

  def self.client
    @client ||= OpenSearch::Client.new(host: Danbooru.config.opensearch_host)
  end
end
