# frozen_string_literal: true

class IndexRebuildJob < ApplicationJob
  queue_as :low_prio

  def perform(klass, id)
    obj = klass.constantize.find(id)
    obj.update_index(defer: false) if obj
  end
end

