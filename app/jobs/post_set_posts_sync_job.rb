# frozen_string_literal: true

class PostSetPostsSyncJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing

  def perform(set_id, added_ids: [], removed_ids: [])
    set = PostSet.find(set_id)
    set.sync_posts_for_delta(added_ids: added_ids, removed_ids: removed_ids)
  rescue ActiveRecord::RecordNotFound
    # Set was deleted; nothing to do.
  end
end
