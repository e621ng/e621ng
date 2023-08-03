class UserFeedback < ApplicationRecord
  self.table_name = "user_feedback"
  belongs_to :user
  belongs_to_creator
  validates :body, :category, presence: true
  validates :category, inclusion: { in: %w[positive negative neutral] }
  validate :creator_is_moderator, on: :create
  validate :user_is_not_creator
  after_save :create_dmail
  after_create do |rec|
    ModAction.log(:user_feedback_create, { user_id: rec.user_id, reason: rec.body, type: rec.category, record_id: rec.id })
  end
  after_update do |rec|
    ModAction.log(:user_feedback_update, { user_id: rec.user_id, reason: rec.body, reason_was: rec.body_before_last_save, type: rec.category, type_was: rec.category_before_last_save, record_id: rec.id })
  end
  after_destroy do |rec|
    ModAction.log(:user_feedback_delete, { user_id: rec.user_id, reason: rec.body, type: rec.category, record_id: rec.id })
    deletion_user = "\"#{CurrentUser.name}\":/users/#{CurrentUser.id}"
    creator_user = "\"#{creator.name}\":/users/#{creator.id}"
    StaffNote.create(body: "#{deletion_user} deleted #{rec.category} feedback, created #{created_at.to_date} by #{creator_user}: #{rec.body}", user_id: rec.user_id, creator: User.system)
  end

  attr_accessor :send_update_dmail

  module SearchMethods
    def positive
      where("category = ?", "positive")
    end

    def neutral
      where("category = ?", "neutral")
    end

    def negative
      where("category = ?", "negative")
    end

    def for_user(user_id)
      where("user_id = ?", user_id)
    end

    def default_order
      order(created_at: :desc)
    end

    def search(params)
      q = super

      q = q.attribute_matches(:body, params[:body_matches])

      q = q.where_user(:user_id, :user, params)
      q = q.where_user(:creator_id, :creator, params)

      if params[:category].present?
        q = q.where("category = ?", params[:category])
      end

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

  def create_dmail
    should_send = saved_change_to_id? || (send_update_dmail.to_s.truthy? && saved_change_to_body?)
    return unless should_send

    action = saved_change_to_id? ? "created" : "updated"
    body = %(#{creator_name} #{action} a "#{category} record":/user_feedbacks?search[user_id]=#{user_id} for your account:\n\n#{self.body})
    Dmail.create_automated(to_id: user_id, title: "Your user record has been updated", body: body)
  end

  def creator_is_moderator
    errors.add(:creator, "must be moderator") unless creator.is_moderator?
  end

  def user_is_not_creator
    errors.add(:creator, "cannot submit feedback for yourself") if user_id == creator_id
  end

  def editable_by?(editor)
    editor.is_moderator? && editor != user
  end
end
