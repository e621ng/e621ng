# frozen_string_literal: true

class UserStatus < ApplicationRecord
  # Karma value of a post that has cleared the review queue. Awarded on approve/queue-bypass,
  # reclaimed on unapprove, and transferred with ownership on replacement.
  KARMA_APPROVED_CREDIT = 1
  # Penalty applied to the uploader when their post is deleted (reversed on undelete).
  KARMA_DELETION_PENALTY = 3
  # Penalty applied to the previous uploader when their post is replaced with penalize enabled.
  KARMA_REPLACEMENT_PENALTY = 1

  belongs_to :user

  def self.for_user(user_id)
    where("user_statuses.user_id = ?", user_id)
  end

  def self.adjust_karma(user_id, delta)
    for_user(user_id).update_all(["upload_karma = upload_karma + ?", delta])
  end
end
