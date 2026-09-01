# frozen_string_literal: true

module DocumentStore
  module Model
    def self.included(klass)
      klass.include(Proxy)

      # In the test env, parallel_test runs multiple processes against separate databases that share
      # one OpenSearch instance. Primary keys overlap across those databases, causing flaky behavior.
      test_suffix = Rails.env.test? ? ENV["TEST_ENV_NUMBER"].presence : nil
      klass.document_store.index_name = "#{klass.model_name.plural}_#{Rails.env}#{test_suffix}"

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

    # Version to stamp on the record's document, for optimistic concurrency control on index writes.
    # Models without a monotonic change counter opt out by leaving this nil.
    # See PostIndex#index_version.
    def index_version
      nil
    end

    def update_index(queue: :high_prio)
      return if Thread.current[:skip_post_index_update]
      return document_store.update_index refresh: "true" if Rails.env.test?

      IndexUpdateJob.set(queue: queue).perform_async(self.class.to_s, id)
    end
  end

  def self.client
    @client ||= OpenSearch::Client.new(host: Danbooru.config.opensearch_host)
  end
end
