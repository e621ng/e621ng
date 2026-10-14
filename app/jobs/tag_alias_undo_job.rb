# frozen_string_literal: true

class TagAliasUndoJob < ApplicationJob
  sidekiq_options queue: "tags", lock: :until_executed, lock_args_method: :lock_args, lock_ttl: 24.hours.to_i

  def self.lock_args(args)
    [args[0]]
  end

  def perform(alias_id, update_topic, undoer_id = nil)
    ta = TagAlias.find(alias_id)
    undoer = User.find_by(id: undoer_id)
    ta.process_undo!(update_topic: update_topic, undoer: undoer)
  rescue TagAlias::UndoError => e
    # These conditions never self-heal, so retrying is pointless; tell the
    # undoer what happened instead.
    return if undoer_id.blank?

    Dmail.create_automated(
      to_id: undoer_id,
      title: "Tag alias ##{alias_id} could not be undone",
      body: "The undo of \"tag alias ##{alias_id}\":/tag_aliases/#{alias_id} was rejected: #{e.message}",
    )
  end
end
