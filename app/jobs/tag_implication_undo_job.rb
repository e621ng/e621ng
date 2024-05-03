# frozen_string_literal: true

class TagImplicationUndoJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    ti = TagImplication.find(args[0])
    ti.process_undo!(update_topic: args[1])
  end
end
