# frozen_string_literal: true

class Award < ApplicationRecord
  belongs_to :award_type
  belongs_to :user
  belongs_to_creator

  validates :award_type_id, uniqueness: { scope: :user_id, message: "has already been given to this user" }

  after_save :create_dmail

  module SearchMethods
    def search(params)
      q = super

      q = q.where_user(:user_id, :user, params)
      q = q.where(award_type_id: params[:award_type_id]) if params[:award_type_id].present?
      q = q.where_user(:creator_id, :creator, params)

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods

  def user_name
    User.id_to_name(user_id)
  end

  def user_name=(name)
    self.user_id = User.name_to_id(name)
  end

  def can_destroy?(user)
    user.is_admin? || user.id == creator_id
  end

  def create_dmail
    body = %(You have been granted the "#{award_type.name}" award by #{User.id_to_name(creator_id)}.\nCongratulations!)
    Dmail.create_automated(to_id: user_id, title: "New Award", body: body, no_email_notification: true)
  end
end
