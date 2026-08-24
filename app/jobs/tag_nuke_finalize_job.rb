# frozen_string_literal: true

class TagNukeFinalizeJob < ApplicationJob
  queue_as :tags

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
