# frozen_string_literal: true

class IndexUpdateJob < ApplicationJob
  queue_as :high_prio
  sidekiq_options lock: :until_executing

  def perform(klass, id)
    obj = klass.constantize.find(id)
    obj.document_store.update_index
  rescue ActiveRecord::RecordNotFound
    # Do nothing
  end
end
