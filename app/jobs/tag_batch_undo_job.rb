# frozen_string_literal: true

class TagBatchUndoJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    TagBatchJob.process_undo!(args[0])
  end
end
