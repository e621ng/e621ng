# frozen_string_literal: true

class TagImplicationFinalizeJob < ApplicationJob
  # Keyed on full args: an undo-finalize (id, name, true) must not dedup against a
  # queued approve-finalize (id, name), or the survivor skips the undo reindex.
  sidekiq_options queue: "tags", lock: :until_executed, lock_ttl: 24.hours.to_i

  # Sidekiq args are positional JSON; keywords are not an option here.
  def perform(implication_id, reindex_tag_name, undo = false) # rubocop:disable Style/OptionalBooleanParameter
    ti = TagImplication.find_by(id: implication_id)
    return unless ti

    # Posts edited since processing may no longer match the tag query but
    # still need reindexing after an undo; the undo rows enumerate them. On
    # the approval path they all still match the tag query, so this would
    # only reimport the same documents.
    post_ids = undo ? ti.tag_rel_undos.flat_map(&:post_ids).uniq : []

    Post.without_timeout do
      Post.document_store.import(
        query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", reindex_tag_name],
      )
      Post.document_store.import(query: { id: post_ids }) if post_ids.any?

      # Post counts may have drifted out of sync, or may have been inaccurate
      # due to legacy data. Recalculate them to ensure they are correct.
      ti.antecedent_tag&.fix_post_count
      ti.consequent_tag&.fix_post_count
    end
  end
end
