# frozen_string_literal: true

class TagAliasUndoJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    ta = TagAlias.find(args[0])
    undoer = User.find_by(id: args[2])
    ta.process_undo!(update_topic: args[1], undoer: undoer)
  end
end
