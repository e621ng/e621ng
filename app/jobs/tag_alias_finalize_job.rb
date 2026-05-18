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
    Post.document_store.import(
      query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", reindex_tag_name],
    )
    ta.antecedent_tag&.fix_post_count
    ta.consequent_tag&.fix_post_count
  end
end
