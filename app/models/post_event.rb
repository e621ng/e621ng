# frozen_string_literal: true

class PostEvent < ApplicationRecord
  belongs_to :creator, class_name: "User"
  enum :action, {
    deleted: 0,
    undeleted: 1,
    approved: 2,
    unapproved: 3,
    flag_created: 4,
    flag_removed: 5,
    favorites_moved: 6,
    favorites_received: 7,
    rating_locked: 8,
    rating_unlocked: 9,
    status_locked: 10,
    status_unlocked: 11,
    note_locked: 12,
    note_unlocked: 13,
    comment_locked: 18,
    comment_unlocked: 19,
    comment_disabled: 22,
    comment_enabled: 23,
    replacement_accepted: 14,
    replacement_rejected: 15,
    replacement_promoted: 20,
    replacement_deleted: 16,
    expunged: 17,
    changed_bg_color: 21,
    replacement_penalty_changed: 24,
  }
  MOD_ONLY_SEARCH_ACTIONS = [
    actions[:comment_locked],
    actions[:comment_unlocked],
    actions[:comment_disabled],
    actions[:comment_enabled],
  ].freeze

  def self.add(post_id, creator, action, data = {})
    create!(post_id: post_id, creator: creator, action: action.to_s, extra_data: data)
  end

  def is_creator_visible?(user)
    case action
    when "flag_created"
      user.can_view_flagger?(creator_id)
    else
      true
    end
  end

  def self.search(params)
    q = super

    if params[:post_id].present?
      q = q.where(post_id: params[:post_id])
    end

    q = q.where_user(:creator_id, :creator, params) do |condition, user_ids|
      condition.where.not(
        action: actions[:flag_created],
        creator_id: user_ids.reject { |user_id| CurrentUser.can_view_flagger?(user_id) },
      )
    end

    if params[:action].present?
      if !CurrentUser.user.is_moderator? && MOD_ONLY_SEARCH_ACTIONS.include?(actions[params[:action]])
        raise(User::PrivilegeError)
      end
      q = q.where(action: actions[params[:action]])
    end

    q.apply_basic_order(params)
  end

  def self.search_options_for(user)
    options = actions.keys
    return options if user.is_moderator?
    options.reject { |action| MOD_ONLY_SEARCH_ACTIONS.any?(actions[action]) }
  end
end
