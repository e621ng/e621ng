# frozen_string_literal: true

class SavedSearchBadgeJob < ApplicationJob
  # No retries: the next page load with a cold cache enqueues a fresh run anyway
  sidekiq_options queue: "low_prio", retry: false, lock: :until_executing, lock_ttl: 15.minutes.to_i

  # safe_mode comes from the enqueuing request; there is no ambient value here.
  def perform(user_id, safe_mode = false) # rubocop:disable Style/OptionalBooleanParameter
    user = User.find_by(id: user_id)
    return unless user&.has_tracked_saved_searches
    SavedSearch.refresh_badge_counts!(user, safe_mode: safe_mode)
  end
end
