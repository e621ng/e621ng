# frozen_string_literal: true

class BulkIndexUpdateJob < ApplicationJob
  sidekiq_options queue: "default"

  def perform(klass_name, ids)
    klass = klass_name.constantize
    klass.without_timeout do
      klass.document_store.import(query: { id: ids })
    end
  end
end
