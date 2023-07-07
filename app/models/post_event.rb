class PostEvent < ApplicationRecord
  belongs_to :creator, class_name: "User"
  enum action: {
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
    comment_disabled: 18,
    comment_enabled: 19,
    replacement_accepted: 14,
    replacement_rejected: 15,
    replacement_promoted: 20,
    replacement_deleted: 16,
    expunged: 17,
  }

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

  def self.for_user(q, user_id)
    q = q.where("creator_id = ?", user_id)
    unless CurrentUser.can_view_flagger?(user_id)
      q = q.where.not(action: actions[:flag_created])
    end
    q
  end

  def self.search(params)
    q = super

    unless CurrentUser.is_moderator?
      q = q.where.not(action: [actions[:comment_disabled], actions[:comment_enabled]])
    end
    if params[:post_id].present?
      q = q.where("post_id = ?", params[:post_id].to_i)
    end

    if params[:creator_name].present?
      creator_id = User.name_to_id(params[:creator_name].strip)
      q = for_user(q, creator_id.to_i)
    end

    if params[:creator_id].present?
      q = for_user(q, params[:creator_id].to_i)
    end

    if params[:action].present?
      q = q.where('action = ?', actions[params[:action]])
    end

    q.apply_basic_order(params)
  end
end
