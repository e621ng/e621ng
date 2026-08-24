# frozen_string_literal: true

class TagBatchFinalizeJob < ApplicationJob
  queue_as :tags
  # Keyed on full args: an enqueue carrying stragglers must never dedup away against a pending one.
  # Currently inert either way — sidekiq-unique-jobs cannot see through the ActiveJob wrapper.
  sidekiq_options lock: :until_executed

  def perform(consequent, straggler_ids = [])
    Post.without_timeout do
      Post.document_store.import(
        query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", consequent],
      )
      # Posts whose save dropped or rewrote the consequent, so the query above misses them.
      Post.document_store.import(query: { id: straggler_ids }) if straggler_ids.any?
    end
  end
end
