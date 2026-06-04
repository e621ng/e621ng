# frozen_string_literal: true

class PostDeletion < ApplicationRecord
  belongs_to :post
  belongs_to :deleter, class_name: "User"
  belongs_to :undeleter, class_name: "User", optional: true

  validates :reason, presence: true

  after_create :log_deletion_event

  def self.current_for(post)
    find_by(post_id: post.id, is_undeleted: false)
  end

  def stamp_undeleted!(undeleter)
    update!(is_undeleted: true, undeleter: undeleter, undeleted_at: Time.current)
    PostEvent.add(post_id, undeleter, :undeleted)
  end

  def can_appeal?(user = CurrentUser.user)
    return false if is_undeleted?
    return false unless appealable_by?(user)
    return false if has_user_appealed?(user)
    true
  end

  def user_appeal(user)
    return nil unless appealable_by?(user)

    @user_appeal ||= {}
    unless @user_appeal.key?(user.id)
      # Multiple appeals used to be possible, so return the latest
      @user_appeal[user.id] = Appeal.where(
        creator_id: user.id,
        qtype: "post_deletion",
        disp_id: id,
      ).order(id: :desc).limit(1).first
    end
    @user_appeal[user.id]
  end

  def has_user_appealed?(user)
    user_appeal(user).present?
  end

  private

  # This is only a basic permission check, ignoring current deletion or appeal status.
  def appealable_by?(user)
    # Uploaders can appeal except for takedowns, verified artists can appeal deletions of their own posts
    (post.uploader_id == user.id && reason !~ /takedown #\d+/i) || post.linked_users.include?(user.id)
  end

  def log_deletion_event
    PostEvent.add(post_id, deleter, :deleted, { reason: reason })
  end
end
