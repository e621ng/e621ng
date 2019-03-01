class Blip < ApplicationRecord
  belongs_to_creator
  validates_presence_of :body
  belongs_to :parent, class_name: "Blip", foreign_key: "response_to", optional: true
  has_many :responses, class_name: "Blip", foreign_key: "response_to"
  validates_length_of :body, within: 5..1000
  validate :validate_parent_exists, :on => :create
  validate :validate_creator_is_not_limited, :on => :create

  def response?
    parent.present?
  end

  def has_responses?
    responses.any?
  end

  def validate_creator_is_not_limited
    unless creator.can_comment?
      errors.add(:base, "You may not create blips until your account is three days old")
    end
  end

  def validate_parent_exists
    if response_to.present?
      errors.add(:response_to, "must exist") unless Blip.exists?(response_to)
    end
  end

  module ApiMethods
    def hidden_attributes
      super + [:body_index]
    end

    def method_attributes
      super + [:creator_name]
    end

    def creator_name
      User.id_to_name(creator_id)
    end
  end

  module PermissionsMethods
    def can_hide?(user)
      user.is_moderator? || user.id == creator_id
    end

    def can_edit?(user)
      (creator_id == user.id && created_at > 5.minutes.ago) || user.is_moderator?
    end

    def visible_to?(user)
      return true unless is_hidden
      user.is_moderator? || user.id == creator_id
    end
  end

  module SearchMethods
    def visible(user = CurrentUser.user)
      where('is_hidden = ?', false) unless user.is_moderator?
    end

    def for_creator(user_id)
      user_id.present? ? where("creator_id = ?", user_id) : none
    end

    def for_creator_name(user_name)
      for_creator(User.name_to_id(user_name))
    end

    def search(params)
      q = super

      q = q.includes(:creator).includes(:responses).includes(:parent)

      q = q.attribute_matches(:body, params[:body_matches], index_column: :body_index)

      if params[:response_to].present?
        q = q.where('response_to = ?', params[:response_to].to_i)
      end

      if params[:creator_name].present?
        q = q.for_creator_name(params[:creator_name])
      end

      if params[:creator_id].present?
        q = q.for_creator(params[:creator_id].to_i)
      end

      case params[:order]
      when "updated_at", "updated_at_desc"
        q = q.order("blips.updated_at DESC")
      else
        q = q.order('id DESC')
      end

      q
    end
  end

  include PermissionsMethods
  extend SearchMethods
  include ApiMethods
end
