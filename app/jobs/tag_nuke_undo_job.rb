# frozen_string_literal: true

class TagNukeUndoJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    TagNukeJob.process_undo!(args[0])
  end
end
