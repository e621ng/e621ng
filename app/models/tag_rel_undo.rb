# frozen_string_literal: true

class TagRelUndo < ApplicationRecord
  belongs_to :tag_rel, polymorphic: true

  # Formats that predate undo support: the TagAlias / TagNukeJob flat array of
  # post ids, and the TagImplication { post_id => tag_string } hash.
  def legacy?
    undo_data.is_a?(Array) || (undo_data.is_a?(Hash) && !undo_data.key?("kind"))
  end

  def posts_chunk?
    undo_data.is_a?(Hash) && undo_data["kind"] == "posts"
  end

  def side_effects?
    undo_data.is_a?(Hash) && undo_data["kind"] == "side_effects"
  end

  def post_ids
    if undo_data.is_a?(Array)
      undo_data
    elsif posts_chunk?
      undo_data["added"].keys.map(&:to_i)
    elsif side_effects?
      []
    else
      # Legacy TagImplication format: { post_id => tag_string }
      undo_data.keys.map(&:to_i)
    end
  end
end
