# frozen_string_literal: true

class TagImplicationFinalizeJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(implication_id, reindex_tag_name)
    ti = TagImplication.find_by(id: implication_id)
    return unless ti
    Post.without_timeout do
      Post.document_store.import(
        query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", reindex_tag_name],
      )

      # Post counts may have drifted out of sync, or may have been inaccurate
      # due to legacy data. Recalculate them to ensure they are correct.
      ti.antecedent_tag&.fix_post_count
      ti.consequent_tag&.fix_post_count
    end
  end
end
