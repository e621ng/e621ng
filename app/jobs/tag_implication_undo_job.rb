# frozen_string_literal: true

class TagImplicationUndoJob < ApplicationJob
  sidekiq_options queue: "tags", lock: :until_executed, lock_args_method: :lock_args, lock_ttl: 24.hours.to_i

  def self.lock_args(args)
    [args[0]]
  end

  def perform(implication_id, update_topic, undoer_id = nil)
    ti = TagImplication.find(implication_id)
    undoer = User.find_by(id: undoer_id)
    ti.process_undo!(update_topic: update_topic, undoer: undoer)
  rescue TagImplication::UndoError => e
    # These conditions never self-heal, so retrying is pointless; tell the
    # undoer what happened instead.
    return if undoer_id.blank?

    Dmail.create_automated(
      to_id: undoer_id,
      title: "Tag implication ##{implication_id} could not be undone",
      body: "The undo of \"tag implication ##{implication_id}\":/tag_implications/#{implication_id} was rejected: #{e.message}",
    )
  end
end
