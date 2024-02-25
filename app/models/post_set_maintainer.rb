# frozen_string_literal: true

class PostSetMaintainer < ApplicationRecord
  belongs_to :user
  belongs_to :post_set

  validate :ensure_not_set_owner, on: :create
  validate :ensure_set_public, on: :create
  validate :ensure_maintainer_count, on: :create
  validate :ensure_not_duplicate, on: :create

  after_create :notify_maintainer

  def notify_maintainer
    body = "\"#{post_set.creator.name}\":/users/#{post_set.creator_id} invited you to be a maintainer of the \"#{post_set.name}\":/post_sets/#{post_set_id} set. This would allow you to add and remove posts from it.

\"Click here\":/post_set_maintainers/#{id}/approve to approve the request and become a maintainer.

\"Click here\":/post_set_maintainers/#{id}/deny to deny the request.

\"Click here\":/post_set_maintainers/#{id}/block to deny the request and prevent yourself from being invited to this set again in the future."
    Dmail.create_automated(
        to_id: user_id,
        title: "You were invite to be a maintainer of #{post_set.name}",
        body: body
    )
  end

  def cancel!
    if status == 'pending'
      self.status = 'cooldown'
      save
      return
    end

    if status == 'approved'
      body = "\"#{post_set.creator.name}\":/users/#{post_set.creator_id} removed you as a maintainer of the \"#{post_set.name}\":/post_sets/#{post_set.id} set."
      Dmail.create_automated(
          to_id: user_id,
          title: "You were removed as a set maintainer of #{post_set.name}",
          body: body
      )
    end
    destroy
  end

  def approve!
    self.status = 'approved'
    save
    Dmail.create_automated(
        to_id: post_set.creator_id,
        title: "#{user.name} approved your invite to maintain #{post_set.name}",
        body: "\"#{user.name}\":/users/#{user_id} approved your invite to maintain \"#{post_set.name}\":/post_sets/#{post_set.id}."
    )
  end

  def deny!
    if status == "pending"
      Dmail.create_automated(
          to_id: post_set.creator_id,
          title: "#{user.name} denied your invite to maintain #{post_set.name}",
          body: "\"#{user.name}\":/users/#{user.id} denied your invite to maintain \"#{post_set.name}\":/post_sets/#{post_set.id}."
      )
    elsif status == "approved"
      Dmail.create_automated(
          to_id: post_set.creator_id,
          title: "#{user.name} removed themselves as a maintainer of #{post_set.name}",
          body: "\"#{user.name}\":/users/#{user.id} removed themselves as a maintainer of \"#{post_set.name}\":/post_sets/#{post_set.id}."
      )
    end
    destroy
  end

  def block!
    if status == "approved"
      Dmail.create_automated(
          to_id: post_set.creator_id,
          title: "#{user.name} removed themselves as a maintainer of #{post_set.name}",
          body: "\"#{user.name}\":/users/#{user.id} removed themselves as a maintainer of \"#{post_set.name}\":/post_sets/#{post_set.id} and blocked all future invites."
      )
    elsif status == "pending"
      Dmail.create_automated(
          to_id: post_set.creator_id,
          title: "#{user.name} denied your invite to maintain #{post_set.name}",
          body: "\"#{user.name}\":/users/#{user.id} denied your invite to maintain \"#{post_set.name}\":/post_sets/#{post_set.id} and blocked all future invites."
      )
    end
    self.status = 'blocked'
    save
  end

  module ValidaitonMethods
    def ensure_not_set_owner
      if post_set.creator_id == user_id
        errors.add(:user, "owns this set and can't be added as a maintainer")
        false
      end
    end

    def ensure_maintainer_count
      if PostSetMaintainer.where(post_set_id: post_set_id).count >= 75
        errors.add(:post_set, "current have too many maintainers")
        false
      end
    end

    def ensure_not_duplicate
      existing = PostSetMaintainer.where(post_set_id: post_set_id, user_id: user_id).first
      if existing.nil?
        return
      end
      if ['approved', 'pending'].include?(existing.status)
        errors.add(:base, "Already a maintainer of this set")
        return false
      end
      if existing.status == 'blocked'
        errors.add(:base, 'User has blocked you from inviting them to maintain this set')
        return false
      end
      if existing.status == 'cooldown' && existing.created_at > 24.hours.ago
        errors.add(:base, "User has been invited to maintain this set too recently")
        return false
      end
    end

    def ensure_set_public
      unless post_set.is_public
        errors.add(:post_set, 'must be public')
        false
      end
    end
  end

  def self.active
    where(status: 'approved')
  end

  def self.pending
    where(status: 'pending')
  end

  include ValidaitonMethods
end
