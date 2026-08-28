# frozen_string_literal: true

class TagNukeFinalizeJob < ApplicationJob
  # Keyed on full args: an enqueue carrying stragglers must never dedup away against a pending one.
  sidekiq_options queue: "tags", lock: :until_executed, lock_ttl: 24.hours.to_i

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
