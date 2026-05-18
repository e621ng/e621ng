# frozen_string_literal: true

class BulkIndexUpdateJob < ApplicationJob
  queue_as :default

  def perform(klass_name, ids)
    klass = klass_name.constantize
    klass.document_store.import(query: { id: ids })
  end
end
