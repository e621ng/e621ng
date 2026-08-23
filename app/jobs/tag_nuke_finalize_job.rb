# frozen_string_literal: true

class TagNukeFinalizeJob < ApplicationJob
  queue_as :tags

  def perform(tag_id)
    # The tag is gone from every post by now, so the affected set only survives
    # in the undo rows the nuke recorded before it started.
    post_ids = TagRelUndo.where(tag_rel_type: "Tag", tag_rel_id: tag_id).unapplied.flat_map(&:post_ids).uniq
    return if post_ids.empty?

    Post.without_timeout do
      Post.document_store.import(query: { id: post_ids })
    end
  end
end
