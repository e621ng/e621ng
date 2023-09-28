# frozen_string_literal: true

class OsIndexUpdateJob < ApplicationJob
  queue_as :os
  sidekiq_options lock: :until_executing

  def perform(klass, id)
    obj = klass.constantize.find(id)
    obj.document_store.os_update_index
  rescue ActiveRecord::RecordNotFound
    # Do nothing
  end
end
