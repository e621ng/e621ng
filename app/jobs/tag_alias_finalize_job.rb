# frozen_string_literal: true

class TagAliasFinalizeJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(alias_id, reindex_tag_name)
    ta = TagAlias.find_by(id: alias_id)
    return unless ta
    Post.without_timeout do
      Post.document_store.import(
        query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", reindex_tag_name],
      )

      # Post counts may have drifted out of sync, or may have been inaccurate
      # due to legacy data. Recalculate them to ensure they are correct.
      ta.antecedent_tag&.fix_post_count
      ta.consequent_tag&.fix_post_count

      # Update the tag alias's post count with the recalculated value.
      ta.update(post_count: ta.consequent_tag&.post_count || 0)
    end
  end
end
