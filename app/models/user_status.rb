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

  # Applies the karma delta and records it in the upload_karma_events ledger,
  # atomically. RETURNING captures the post-change balance race-free.
  def self.adjust_karma(user_id, delta, reason, post_id: nil, data: {})
    return if delta == 0
    transaction do
      result = connection.exec_query(
        sanitize_sql(["UPDATE user_statuses SET upload_karma = upload_karma + ? WHERE user_id = ? RETURNING upload_karma", delta, user_id]),
      )
      # No user_statuses row — the same silent no-op update_all used to be.
      next if result.rows.empty?

      UploadKarmaEvent.create!(
        user_id: user_id,
        creator_id: CurrentUser.id,
        post_id: post_id,
        reason: reason,
        delta: delta,
        balance: result.rows[0][0],
        extra_data: data,
      )
    end
  end
end
