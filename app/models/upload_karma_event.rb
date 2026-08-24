# frozen_string_literal: true

class UploadKarmaEvent < ApplicationRecord
  belongs_to :user
  belongs_to :creator, class_name: "User"

  enum :reason, {
    approved: 0,
    unapproved: 1,
    deleted: 2,
    undeleted: 3,
    replacement_penalty: 4,
    replacement_penalty_reversed: 5,
    replacement_transfer: 6,
    owner_change: 7,
    staff_override: 8,
    queue_bypass: 9,
  }

  # Ledger rows are immutable: created once, never updated or destroyed.
  def readonly?
    persisted?
  end

  def self.search(params)
    q = super
    q = q.where_user(:user_id, :user, params)
    q = q.where_user(:creator_id, :creator, params)
    q = q.where(post_id: params[:post_id]) if params[:post_id].present?
    q = q.where(reason: reasons[params[:reason]]) if params[:reason].present?
    q.apply_basic_order(params)
  end

  def description
    base = case reason
           when "approved" then "Post approved"
           when "unapproved" then "Post unapproved"
           when "deleted" then extra_data["credit_reversed"] ? "Post deleted (approval credit reversed)" : "Post deleted"
           when "undeleted" then "Post restored"
           when "replacement_penalty" then "Post replaced with penalty"
           when "replacement_penalty_reversed" then "Replacement penalty lifted"
           when "replacement_transfer" then delta > 0 ? "Approval credit received with replacement" : "Approval credit lost to replacement"
           when "owner_change" then user_id == extra_data["new_owner"] ? "Received post ownership" : "Lost post ownership"
           when "staff_override" then "Karma manually set to #{extra_data['new_karma']}"
           when "queue_bypass" then "Post published without review"
           end
    extra_data["backfill"] ? "#{base} (recalculated)" : base
  end
end
