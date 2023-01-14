# frozen_string_literal: true

class IndexUpdateJobCopy < ApplicationJob
  queue_as :high_prio
  sidekiq_options lock: :until_executing

  def perform(klass, id)
    begin
      obj = klass.constantize.find(id)
      obj.update_index(defer: false) if obj
    rescue ActiveRecord::RecordNotFound
      return
    end
  end
end
