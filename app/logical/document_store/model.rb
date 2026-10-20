# frozen_string_literal: true

module DocumentStore
  module Model
    def self.included(klass)
      klass.include(Proxy)

      # In the test env, parallel_test runs multiple processes against separate databases that share
      # one OpenSearch instance. Primary keys overlap across those databases, causing flaky behavior.
      test_suffix = Rails.env.test? ? ENV["TEST_ENV_NUMBER"].presence : nil
      klass.document_store.index_name = "#{klass.model_name.plural}_#{Rails.env}#{test_suffix}"

      # Create and destroy write inline, so a rejected write would fail the request after the
      # record was already committed. Defer those; IndexUpdateJob/IndexDeleteJob retry with backoff.
      klass.after_commit on: [:create] do
        document_store.update_index(refresh: Rails.env.test?.to_s)
      rescue OpenSearch::Transport::Transport::Errors::TooManyRequests => e
        DocumentStore.defer_rejected_write(IndexUpdateJob, self, e)
      end

      klass.after_commit on: [:update] do
        update_index
      end

      klass.after_commit on: [:destroy] do
        document_store.delete_document(refresh: Rails.env.test?.to_s)
      rescue OpenSearch::Transport::Transport::Errors::TooManyRequests => e
        DocumentStore.defer_rejected_write(IndexDeleteJob, self, e)
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

  DEFERRED_WRITE_DELAY = 1.minute

  def self.defer_rejected_write(job, record, error)
    Rails.logger.warn("[DocumentStore] #{record.class.document_store.index_name}/#{record.id} rejected, retrying via #{job.name}: #{error.message.truncate(300)}")
    job.perform_in(DEFERRED_WRITE_DELAY, record.class.to_s, record.id)
    RequestStore[:index_update_delayed] = true
  end

  def self.client
    @client ||= OpenSearch::Client.new(host: Danbooru.config.opensearch_host)
  end
end
