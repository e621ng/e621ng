# frozen_string_literal: true

class UserNameChangeRequest < ApplicationRecord
  after_initialize :initialize_attributes, if: :new_record?
  after_create :apply!

  validates :original_name, :desired_name, presence: true
  validates :desired_name, user_name: { user_id: ->(rec) { rec.user_id } }
  validate :not_limited, on: :create

  belongs_to :user

  attr_accessor :skip_limited_validation

  def initialize_attributes
    self.user_id ||= CurrentUser.user.id
    self.original_name ||= CurrentUser.user.name
  end

  def self.search(params)
    q = super

    q = q.where_user(:user_id, :current, params)

    if params[:original_name].present?
      q = q.where_ilike(:original_name, User.normalize_name(params[:original_name]))
    end

    if params[:desired_name].present?
      q = q.where_ilike(:desired_name, User.normalize_name(params[:desired_name]))
    end

    q.apply_basic_order(params)
  end

  def apply!
    user.update_attribute(:name, desired_name)
  end

  def not_limited
    return if skip_limited_validation == true
    if UserNameChangeRequest.where("user_id = ? and created_at >= ?", CurrentUser.user.id, 1.week.ago).exists?
      errors.add(:base, "You can only submit one name change request per week")
    end
  end
end
