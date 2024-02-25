# frozen_string_literal: true

class ForumTopic < ApplicationRecord
  belongs_to_creator
  belongs_to_updater
  belongs_to :category, class_name: "ForumCategory", foreign_key: :category_id
  has_many :posts, -> {order("forum_posts.id asc")}, :class_name => "ForumPost", :foreign_key => "topic_id", :dependent => :destroy
  has_one :original_post, -> {order("forum_posts.id asc")}, class_name: "ForumPost", foreign_key: "topic_id", inverse_of: :topic
  has_many :subscriptions, :class_name => "ForumSubscription"
  before_validation :initialize_is_hidden, :on => :create
  validate :category_valid
  validates :title, :creator_id, presence: true
  validates_associated :original_post
  validates_presence_of :original_post
  validates :title, :length => {:maximum => 250}
  validate :category_allows_creation, on: :create
  accepts_nested_attributes_for :original_post
  before_destroy :create_mod_action_for_delete
  after_update :update_original_post
  after_save(:if => ->(rec) {rec.saved_change_to_is_locked?}) do |rec|
    ModAction.log(rec.is_locked ? :forum_topic_lock : :forum_topic_unlock, {forum_topic_id: rec.id, forum_topic_title: rec.title, user_id: rec.creator_id})
  end
  after_save(:if => ->(rec) {rec.saved_change_to_is_sticky?}) do |rec|
    ModAction.log(rec.is_sticky ? :forum_topic_stick : :forum_topic_unstick, {forum_topic_id: rec.id, forum_topic_title: rec.title, user_id: rec.creator_id})
  end

  module CategoryMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def for_category_id(cid)
        where(:category_id => cid)
      end
    end

    def category_name
      return '(Unknown)' unless category
      category.name
    end

    def category_valid
      return if category
      errors.add(:category, "is invalid")
      throw :abort
    end

    def category_allows_creation
      if category && !category.can_create_within?(creator)
        errors.add(:category, "does not allow new topics")
        return false
      end
    end
  end

  module SearchMethods
    def active
      where("(forum_topics.is_hidden = false or forum_topics.creator_id = ?)", CurrentUser.id)
    end

    def permitted
      joins(:category).where('forum_categories.can_view <= ?', CurrentUser.level)
    end

    def sticky_first
      order(is_sticky: :desc, updated_at: :desc)
    end

    def default_order
      order(updated_at: :desc)
    end

    def search(params)
      q = super
      q = q.permitted

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

      has_unread_topics = ForumTopic.permitted.active.where("forum_topics.updated_at >= ?", user.last_forum_read_at)
      .joins("left join forum_topic_visits on (forum_topic_visits.forum_topic_id = forum_topics.id and forum_topic_visits.user_id = #{user.id})")
      .where("(forum_topic_visits.id is null or forum_topic_visits.last_read_at < forum_topics.updated_at)")
      .exists?
      unless has_unread_topics
        user.update_attribute(:last_forum_read_at, Time.now)
        ForumTopicVisit.prune!(user)
      end
    end
  end

  module SubscriptionMethods
    def user_subscription(user)
      subscriptions.where(:user_id => user.id).first
    end
  end

  extend SearchMethods
  include CategoryMethods
  include VisitMethods
  include SubscriptionMethods

  def editable_by?(user)
    (creator_id == user.id || user.is_moderator?) && visible?(user)
  end

  def visible?(user)
    return false if is_hidden && !can_hide?(user)
    user.level >= category.can_view
  end

  def can_reply?(user = CurrentUser.user)
    user.level >= category.can_reply
  end

  def can_hide?(user)
    user.is_moderator? || user.id == creator_id
  end

  def can_delete?(user)
    user.is_admin?
  end

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
    (response_count / Danbooru.config.posts_per_page.to_f).ceil
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
end
