# frozen_string_literal: true

class ForumTopic < ApplicationRecord
  belongs_to_creator
  belongs_to_updater
  belongs_to :category, class_name: "ForumCategory", foreign_key: :category_id
  has_many :posts, -> {order("forum_posts.id asc")}, :class_name => "ForumPost", :foreign_key => "topic_id", :dependent => :destroy
  has_one :original_post, -> {order("forum_posts.id asc")}, class_name: "ForumPost", foreign_key: "topic_id", inverse_of: :topic
  has_many :subscriptions, :class_name => "ForumSubscription"

  before_validation :initialize_is_hidden, on: :create
  validates :creator_id, presence: true
  validate :validate_category
  validate :validate_category_allows_creation, on: :create
  validates :original_post, presence: true
  validates_associated :original_post
  validates :title, presence: true
  validates :title, length: { maximum: 250 }

  accepts_nested_attributes_for :original_post
  after_update :update_original_post
  before_destroy :create_mod_action_for_delete
  after_save(:if => ->(rec) {rec.saved_change_to_is_locked?}) do |rec|
    ModAction.log(rec.is_locked ? :forum_topic_lock : :forum_topic_unlock, {forum_topic_id: rec.id, forum_topic_title: rec.title, user_id: rec.creator_id})
  end
  after_save(:if => ->(rec) {rec.saved_change_to_is_sticky?}) do |rec|
    ModAction.log(rec.is_sticky ? :forum_topic_stick : :forum_topic_unstick, {forum_topic_id: rec.id, forum_topic_title: rec.title, user_id: rec.creator_id})
  end

  module AccessMethods
    ### Standard Permissions ###

    def can_access?(user = CurrentUser.user)
      return false if user.blank?
      return false unless category&.can_access?(user)
      return true if user.is_staff?
      return true if user.id == creator_id
      return false if is_hidden?
      true
    end

    def can_edit?(user = CurrentUser.user)
      return false unless can_access?(user)
      return false unless user.is_member?
      return true if user.is_moderator?
      return true if creator_id == user.id
      false
    end

    def can_hide?(user = CurrentUser.user)
      return false unless can_access?(user)
      return false unless user.is_member?
      return true if user.is_moderator?
      return false unless original_post&.can_hide?(user)
      return true if user.id == creator_id
      false
    end

    def can_unhide?(user = CurrentUser.user)
      return false unless can_access?(user)
      return true if user.is_moderator?
      false
    end

    def can_destroy?(user = CurrentUser.user)
      return false unless can_access?(user)
      return true if user.is_admin?
      false
    end

    ### Model Specific ###

    def can_reply?(user = CurrentUser.user)
      return false unless can_access?(user)
      return false unless user.is_member?
      return false if is_locked && !can_lock?(user)
      return true if category.can_reply?(user)
      false
    end

    def can_sticky?(user = CurrentUser.user)
      return false unless can_access?(user)
      return true if user.is_moderator?
      false
    end

    def can_lock?(user = CurrentUser.user)
      return false unless can_access?(user)
      return true if user.is_moderator?
      false
    end
  end

  module CategoryMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def for_category_id(cid)
        where(category_id: cid)
      end
    end

    def category_name
      return "(Unknown)" unless category
      category.name
    end
  end

  module SearchMethods
    def visible(user)
      q = joins(:category).where("forum_categories.can_view <= ?", user.level)
      q = q.where("forum_topics.is_hidden = FALSE OR forum_topics.creator_id = ?", user.id) unless user.is_staff?
      q
    end

    def sticky_first
      order(is_sticky: :desc, updated_at: :desc)
    end

    def default_order
      order(updated_at: :desc)
    end

    def search(params)
      q = super
      q = q.visible(CurrentUser.user)

      q = q.attribute_matches(:title, params[:title_matches])

      if params[:category_id].present?
        q = q.for_category_id(params[:category_id])
      end

      if params[:title].present?
        q = q.where("title = ?", params[:title])
      end

      q = q.attribute_matches(:is_sticky, params[:is_sticky])
      q = q.attribute_matches(:is_locked, params[:is_locked])
      q = q.attribute_matches(:is_hidden, params[:is_hidden])

      case params[:order]
      when "sticky"
        q = q.sticky_first
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  module SubscriptionMethods
    def user_subscription(user)
      subscriptions.where(user_id: user.id).first
    end
  end

  module ValidationMethods
    def validate_category
      return true if category.present?
      errors.add(:category, "is invalid")
      throw :abort
    end

    def validate_category_allows_creation
      return true if category.blank?
      return true if category.can_create?(creator)

      errors.add(:category, "does not allow new topics")
      false
    end
  end

  module VisitMethods
    def read_by?(user = nil)
      user ||= CurrentUser.user

      if user.last_forum_read_at && updated_at <= user.last_forum_read_at
        return true
      end

      user.has_viewed_thread?(id, updated_at)
    end

    def mark_as_read!(user = CurrentUser.user)
      return if user.is_anonymous?

      match = ForumTopicVisit.where(:user_id => user.id, :forum_topic_id => id).first
      if match
        match.update_attribute(:last_read_at, updated_at)
      else
        ForumTopicVisit.create(:user_id => user.id, :forum_topic_id => id, :last_read_at => updated_at)
      end

      has_unread_topics = ForumTopic.visible(user).where("forum_topics.updated_at >= ?", user.last_forum_read_at)
      .joins("left join forum_topic_visits on (forum_topic_visits.forum_topic_id = forum_topics.id and forum_topic_visits.user_id = #{user.id})")
      .where("(forum_topic_visits.id is null or forum_topic_visits.last_read_at < forum_topics.updated_at)")
      .exists?
      unless has_unread_topics
        user.update_attribute(:last_forum_read_at, Time.now)
        ForumTopicVisit.prune!(user)
      end
    end
  end

  extend SearchMethods
  include AccessMethods
  include CategoryMethods
  include SubscriptionMethods
  include ValidationMethods
  include VisitMethods

  def create_mod_action_for_delete
    ModAction.log(:forum_topic_delete, {forum_topic_id: id, forum_topic_title: title, user_id: creator_id})
  end

  def create_mod_action_for_hide
    ModAction.log(:forum_topic_hide, {forum_topic_id: id, forum_topic_title: title, user_id: creator_id})
  end

  def create_mod_action_for_unhide
    ModAction.log(:forum_topic_unhide, {forum_topic_id: id, forum_topic_title: title, user_id: creator_id})
  end

  def initialize_is_hidden
    self.is_hidden = false if is_hidden.nil?
  end

  def last_page
    (response_count / Danbooru.config.records_per_page.to_f).ceil
  end

  def hide!
    update(is_hidden: true)
  end

  def unhide!
    update(is_hidden: false)
  end

  def update_original_post
    if original_post
      original_post.update_columns(:updater_id => CurrentUser.id, :updated_at => Time.now)
    end
  end

  def method_attributes
    super + %i[creator_name updater_name]
  end
end
