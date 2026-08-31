# frozen_string_literal: true

class IndexUpdateJob < ApplicationJob
  sidekiq_options queue: "high_prio", lock: :until_executing, lock_ttl: 1.hour.to_i

  def perform(klass, id)
    obj = klass.constantize.find(id)
    obj.document_store.update_index
  rescue ActiveRecord::RecordNotFound
    # Do nothing
  end
end
