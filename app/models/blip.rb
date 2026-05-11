# frozen_string_literal: true

class Blip < ApplicationRecord
  include UserWarnable
  simple_versioning

  belongs_to_creator
  belongs_to_updater optional: true
  belongs_to :parent, class_name: "Blip", foreign_key: "response_to", optional: true
  belongs_to :warning_user, class_name: "User", optional: true
  has_many :responses, class_name: "Blip", foreign_key: "response_to"
  user_status_counter :blip_count

  normalizes :body, with: ->(body) { body.gsub("\r\n", "\n") }
  validates :body, presence: true
  validates :body, length: { minimum: 5, maximum: Danbooru.config.blip_max_size }
  validate :validate_parent_exists, on: :create
  validate :validate_creator_is_not_limited, on: :create

  after_update(if: ->(rec) { !rec.saved_change_to_is_deleted? && CurrentUser.id != rec.creator_id }) do |rec|
    ModAction.log(:blip_update, { blip_id: rec.id, user_id: rec.creator_id })
  end
  after_destroy do |rec|
    ModAction.log(:blip_destroy, { blip_id: rec.id, user_id: rec.creator_id })
  end
  after_save(if: ->(rec) { rec.saved_change_to_is_deleted? && CurrentUser.id != rec.creator_id }) do |rec|
    action = rec.is_deleted ? :blip_delete : :blip_undelete
    ModAction.log(action, { blip_id: rec.id, user_id: rec.creator_id })
  end

  def is_response?
    parent.present?
  end

  def has_responses?
    responses.any?
  end

  def delete!
    update(is_deleted: true)
  end

  def undelete!
    update(is_deleted: false)
  end

  module AccessMethods
    def is_accessible?(user = CurrentUser.user)
      return true if user.is_staff?
      return true if user.id == creator_id
      return false if is_deleted
      true
    end

    def can_edit?(user = CurrentUser.user)
      return true if user.is_admin?
      return false if was_warned?
      creator_id == user.id && created_at > 5.minutes.ago
    end

    def can_delete?(user = CurrentUser.user)
      return true if user.is_moderator?
      return false if was_warned?
      user.id == creator_id
    end
  end

  module ApiMethods
    def method_attributes
      super + [:creator_name]
    end
  end

  module SearchMethods
    # ============================== #
    # ===== Visibility Methods ===== #
    # ============================== #

    # NOTE: This scope does not currently match the logic in #is_accessible? because
    # there is currently no toggle for showing creators their own deleted blips.
    def accessible(user = CurrentUser)
      if user.is_staff?
        all
      else
        where("is_deleted = ?", false)
      end
    end

    # ============================== #
    # ======= Search Methods ======= #
    # ============================== #

    def search(params)
      q = super.accessible
               .includes(:creator, :responses, :parent)

      # NOTE: If we start to experience performance issues with this,
      # consider similar optimizations used in Comment.search
      q = q.attribute_matches(:body, params[:body_matches])

      if params[:response_to].present?
        q = q.where("response_to = ?", params[:response_to].to_i)
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

    # ============================== #
    # ======= Other Methods ======== #
    # ============================== #

    def for_creator(user_id)
      user_id.present? ? where("creator_id = ?", user_id) : none
    end
  end

  module ValidatorMethods
    def validate_creator_is_not_limited
      allowed = creator.can_blip_with_reason
      if allowed != true
        errors.add(:creator, User.throttle_reason(allowed))
        return false
      end
      true
    end

    def validate_parent_exists
      if response_to.present? && !Blip.exists?(response_to)
        errors.add(:response_to, "must exist")
      end
    end
  end

  include AccessMethods
  include ApiMethods
  extend SearchMethods
  include ValidatorMethods
end
