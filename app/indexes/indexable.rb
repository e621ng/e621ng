# frozen_string_literal: true

# Base Elasticsearch indexing definitions
#
# Make sure to include your custom index file
# in your model alongside Indexable.
module Indexable
  def self.included(base)
    base.include Elasticsearch::Model
    base.include DocumentStore::Model

    base.index_name("#{base.model_name.plural}_#{Rails.env}")

    base.after_commit on: %i[create update] do
      update_index
    end

    base.after_commit on: [:destroy] do
      document_store_delete_document(refresh: Rails.env.test?.to_s)
    end
  end

  def update_index(queue: :high_prio)
    # TODO: race condition hack, makes tests SLOW!!!
    return document_store_update_index refresh: "true" if Rails.env.test?

    IndexUpdateJob.set(queue: queue).perform_later(self.class.to_s, id)
  end
end
