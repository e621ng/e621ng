class UserFeedback < ApplicationRecord
  self.table_name = "user_feedback"
  belongs_to :user
  belongs_to_creator
  attr_accessor :disable_dmail_notification
  validates :user, :creator, :body, :category, presence: true
  validates :category, inclusion: { :in => %w(positive negative neutral) }
  validate :creator_is_moderator, on: :create
  validate :user_is_not_creator
  after_create :create_dmail, unless: :disable_dmail_notification
  after_create do |rec|
    ModAction.log(:user_feedback_create, {user_id: rec.user_id, reason: rec.body, type: rec.category, record_id: rec.id})
  end
  after_update do |rec|
    ModAction.log(:user_feedback_update, {user_id: rec.user_id, reason: rec.body, type: rec.category, record_id: rec.id})
  end
  after_destroy do |rec|
    ModAction.log(:user_feedback_delete, {user_id: rec.user_id, reason: rec.body, type: rec.category, record_id: rec.id})
  end

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

    def visible(viewer = CurrentUser.user)
      if viewer.is_admin?
        all
      else
        # joins(:user).merge(User.undeleted).or(where("body !~ 'Name changed from [^\s:]+ to [^\s:]+'"))
        joins(:user).where.not("users.name ~ 'user_[0-9]+~*' AND user_feedback.body ~ 'Name changed from [^\s:]+ to [^\s:]+'")
      end
    end

    def default_order
      order(created_at: :desc)
    end

    def search(params)
      q = super

      q = q.attribute_matches(:body, params[:body_matches])

      if params[:user_id].present?
        q = q.for_user(params[:user_id].to_i)
      end

      if params[:user_name].present?
        q = q.where("user_id = (select _.id from users _ where lower(_.name) = ?)", params[:user_name].mb_chars.downcase.strip.tr(" ", "_"))
      end

      if params[:creator_id].present?
         q = q.where("creator_id = ?", params[:creator_id].to_i)
      end

      if params[:creator_name].present?
        q = q.where("creator_id = (select _.id from users _ where lower(_.name) = ?)", params[:creator_name].mb_chars.downcase.strip.tr(" ", "_"))
      end

      if params[:category].present?
        q = q.where("category = ?", params[:category])
      end

      q.apply_default_order(params)
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
    body = %{@#{creator_name} created a "#{category} record":/user_feedbacks?search[user_id]=#{user_id} for your account:\n\n#{self.body}}
    Dmail.create_automated(:to_id => user_id, :title => "Your user record has been updated", :body => body)
  end

  def creator_is_moderator
    if !creator.is_moderator?
      errors[:creator] << "must be moderator"
      return false
    elsif creator.no_feedback?
      errors[:creator] << "cannot submit feedback"
      return false
    else
      return true
    end
  end

  def user_is_not_creator
    if user_id == creator_id
      errors[:creator] << "cannot submit feedback for yourself"
      return false
    else
      return true
    end
  end

  def editable_by?(editor)
    (editor.is_moderator? && editor != user)
  end
end
