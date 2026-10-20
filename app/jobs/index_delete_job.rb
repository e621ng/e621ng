# frozen_string_literal: true

class IndexDeleteJob < ApplicationJob
  sidekiq_options queue: "high_prio", lock: :until_executing, lock_ttl: 1.hour.to_i

  def perform(klass, id)
    klass.constantize.document_store.delete_document(id)
  end
end
