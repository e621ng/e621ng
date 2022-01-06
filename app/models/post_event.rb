class PostEvent < ApplicationRecord
  belongs_to :creator, class_name: "User"
  before_validation :initialize_creator, on: :create
  enum action: {
    deleted: 0,
    undeleted: 1,
    approved: 2,
    unapproved: 3,
    favorites_moved: 4,
    favorites_recieved: 5,
    rating_locked: 6,
    rating_unlocked: 7,
    flag_created: 8,
    flag_removed: 9,
    replacement_accepted: 10,
    replacement_rejected: 11,
    replacement_deleted: 12,
    expunged: 13
  }

  def self.add(post_id, action, data = {})
    create!(post_id: post_id, action: action.to_s, extra_data: data)
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

    q.apply_default_order(params)
  end

  def initialize_creator
    self.creator_id = CurrentUser.id
  end

  def hidden_attributes
    hidden = super + [:extra_data]
    hidden += [:creator_id] unless is_creator_visible?(CurrentUser.user)
    hidden
  end
end
