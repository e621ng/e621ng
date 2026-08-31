# frozen_string_literal: true

class SavedSearchBadgeJob < ApplicationJob
  sidekiq_options queue: "low_prio", lock: :until_executing, lock_ttl: 15.minutes.to_i

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.has_tracked_saved_searches
    SavedSearch.refresh_badge_counts!(user)
  end
end
