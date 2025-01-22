# frozen_string_literal: true

class StaffNote < ApplicationRecord
  belongs_to_creator
  belongs_to_updater
  belongs_to :user
  after_create :log_create
  after_update :log_update

  scope :active, -> { where(is_deleted: false) }

  module LogMethods
    def log_create
      ModAction.log(:staff_note_create, { id: id, user_id: user_id, body: body })
    end

    def log_update
      if saved_change_to_body?
        ModAction.log(:staff_note_update, { id: id, user_id: user_id, body: body, old_body: body_before_last_save })
      end

      if saved_change_to_is_deleted?
        if is_deleted?
          ModAction.log(:staff_note_delete, { id: id, user_id: user_id })
        else
          ModAction.log(:staff_note_undelete, { id: id, user_id: user_id })
        end
      end
    end
  end

  module SearchMethods
    def search(params)
      q = super

      q = q.attribute_matches(:resolved, params[:resolved])
      q = q.attribute_matches(:body, params[:body_matches])
      q = q.where_user(:user_id, :user, params)
      q = q.where_user(:creator_id, :creator, params)
      q = q.where_user(:updater_id, :updater, params)

      if params[:without_system_user]&.truthy?
        q = q.where.not(creator: User.system)
      end

      if params[:is_deleted].present?
        q = q.attribute_matches(:is_deleted, params[:is_deleted])
      elsif !params[:include_deleted]&.truthy?
        q = q.active
      end

      q.apply_basic_order(params)
    end

    def default_order
      order("id desc")
    end
  end

  include LogMethods
  extend SearchMethods

  def user_name
    User.id_to_name(user_id)
  end

  def user_name=(name)
    self.user_id = User.name_to_id(name)
  end

  def can_edit?(user)
    return false unless user.is_staff?
    user.id == creator_id || user.is_admin?
  end

  def can_delete?(user)
    return false unless user.is_staff?
    user.id == creator_id || user.is_admin?
  end
end
