# frozen_string_literal: true

class TagImplicationUndoJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  # These conditions never self-heal, so retrying is pointless; tell the
  # undoer what happened instead.
  discard_on TagImplication::UndoError do |job, error|
    implication_id, _update_topic, undoer_id = job.arguments
    next if undoer_id.blank?

    Dmail.create_automated(
      to_id: undoer_id,
      title: "Tag implication ##{implication_id} could not be undone",
      body: "The undo of \"tag implication ##{implication_id}\":/tag_implications/#{implication_id} was rejected: #{error.message}",
    )
  end

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    ti = TagImplication.find(args[0])
    undoer = User.find_by(id: args[2])
    ti.process_undo!(update_topic: args[1], undoer: undoer)
  end
end
