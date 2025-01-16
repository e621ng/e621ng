# frozen_string_literal: true

class Blip < ApplicationRecord
  include UserWarnable
  simple_versioning
  belongs_to_creator
  belongs_to_updater optional: true
  normalizes :body, with: ->(body) { body.gsub("\r\n", "\n") }
  validates :body, presence: true
  validates :body, length: { minimum: 5, maximum: Danbooru.config.blip_max_size }
  validate :validate_parent_exists, on: :create
  validate :validate_creator_is_not_limited, on: :create

  after_update(if: ->(rec) { !rec.saved_change_to_is_hidden? && CurrentUser.id != rec.creator_id }) do |rec|
    ModAction.log(:blip_update, { blip_id: rec.id, user_id: rec.creator_id })
  end
  after_destroy do |rec|
    ModAction.log(:blip_delete, { blip_id: rec.id, user_id: rec.creator_id })
  end
  after_save(if: ->(rec) { rec.saved_change_to_is_hidden? && CurrentUser.id != rec.creator_id }) do |rec|
    action = rec.is_hidden? ? :blip_hide : :blip_unhide
    ModAction.log(action, { blip_id: rec.id, user_id: rec.creator_id })
  end

  user_status_counter :blip_count
  belongs_to :parent, class_name: "Blip", foreign_key: "response_to", optional: true
  belongs_to :warning_user, class_name: "User", optional: true
  has_many :responses, class_name: "Blip", foreign_key: "response_to"

  def response?
    parent.present?
  end

  def has_responses?
    responses.any?
  end

  def validate_creator_is_not_limited
    allowed = creator.can_blip_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def validate_parent_exists
    if response_to.present?
      errors.add(:response_to, "must exist") unless Blip.exists?(response_to)
    end
  end

  module ApiMethods
    def method_attributes
      super + [:creator_name]
    end
  end

  module PermissionsMethods
    def can_edit?(user)
      return true if user.is_admin?
      return false if was_warned?
      creator_id == user.id && created_at > 5.minutes.ago
    end

    def can_hide?(user)
      return true if user.is_moderator?
      return false if was_warned?
      user.id == creator_id
    end

    def visible_to?(user)
      return true unless is_hidden
      user.is_moderator? || user.id == creator_id
    end
  end

  module SearchMethods
    def visible(user = CurrentUser)
      if user.is_moderator?
        all
      else
        where('is_hidden = ?', false)
      end
    end

    def for_creator(user_id)
      user_id.present? ? where("creator_id = ?", user_id) : none
    end

    def search(params)
      q = super

      q = q.includes(:creator).includes(:responses).includes(:parent)

      q = q.attribute_matches(:body, params[:body_matches])

      if params[:response_to].present?
        q = q.where('response_to = ?', params[:response_to].to_i)
      end

      q = q.where_user(:creator_id, :creator, params)

      if params[:ip_addr].present?
        q = q.where("creator_ip_addr <<= ?", params[:ip_addr])
      end

      case params[:order]
      when "updated_at", "updated_at_desc"
        q = q.order("blips.updated_at DESC")
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  include PermissionsMethods
  extend SearchMethods
  include ApiMethods

  def hide!
    update(is_hidden: true)
  end

  def unhide!
    update(is_hidden: false)
  end
end
