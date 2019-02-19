# frozen_string_literal: true

class IndexUpdateJob < ApplicationJob
  queue_as :high_prio

  def perform(klass, id)
    obj = klass.constantize.find_by(id)
    obj.update_index(defer: false) if obj
  end
end
