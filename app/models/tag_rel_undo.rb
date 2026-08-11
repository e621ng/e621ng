# frozen_string_literal: true

class TagRelUndo < ApplicationRecord
  belongs_to :tag_rel, polymorphic: true

  # Original TagAlias / TagNukeJob format: a flat array of post ids.
  def legacy?
    undo_data.is_a?(Array)
  end

  def posts_chunk?
    undo_data.is_a?(Hash) && undo_data["kind"] == "posts"
  end

  def side_effects?
    undo_data.is_a?(Hash) && undo_data["kind"] == "side_effects"
  end

  def post_ids
    if legacy?
      undo_data
    elsif posts_chunk?
      undo_data["with_consequent"] + undo_data["without_consequent"]
    elsif side_effects?
      []
    else
      # TagImplication format: { post_id => tag_string }
      undo_data.keys.map(&:to_i)
    end
  end
end
