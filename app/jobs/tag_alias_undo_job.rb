# frozen_string_literal: true

class TagAliasUndoJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  # These conditions never self-heal, so retrying is pointless; tell the
  # undoer what happened instead.
  discard_on TagAlias::UndoError do |job, error|
    alias_id, _update_topic, undoer_id = job.arguments
    next if undoer_id.blank?

    Dmail.create_automated(
      to_id: undoer_id,
      title: "Tag alias ##{alias_id} could not be undone",
      body: "The undo of \"tag alias ##{alias_id}\":/tag_aliases/#{alias_id} was rejected: #{error.message}",
    )
  end

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    ta = TagAlias.find(args[0])
    undoer = User.find_by(id: args[2])
    ta.process_undo!(update_topic: args[1], undoer: undoer)
  end
end
