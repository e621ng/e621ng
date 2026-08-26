# frozen_string_literal: true

class TagNukeFinalizeJob < ApplicationJob
  queue_as :tags
  # Keyed on full args: an enqueue carrying stragglers must never dedup away against a pending one.
  # Currently inert either way — sidekiq-unique-jobs cannot see through the ActiveJob wrapper.
  sidekiq_options lock: :until_executed

  def perform(tag_id, straggler_ids = [])
    # The tag is gone from every post by now, so the set only survives in the nuke's undo rows.
    post_ids = TagRelUndo.where(tag_rel_type: "Tag", tag_rel_id: tag_id).unapplied.flat_map(&:post_ids)
    # Stragglers arrive explicitly because their undo row may never have been written.
    post_ids |= straggler_ids
    return if post_ids.empty?

    Post.without_timeout do
      Post.document_store.import(query: { id: post_ids })
    end
  end
end
