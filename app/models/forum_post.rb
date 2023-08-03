class ForumPost < ApplicationRecord
  include UserWarnable
  simple_versioning
  attr_readonly :topic_id
  belongs_to_creator
  belongs_to_updater
  user_status_counter :forum_post_count
  belongs_to :topic, :class_name => "ForumTopic"
  has_many :votes, class_name: "ForumPostVote"
  has_one :tag_alias
  has_one :tag_implication
  has_one :bulk_update_request
  before_validation :initialize_is_hidden, :on => :create
  after_create :update_topic_updated_at_on_create
  after_destroy :update_topic_updated_at_on_destroy
  validates :body, :creator_id, presence: true
  validates :body, length: { minimum: 1, maximum: Danbooru.config.forum_post_max_size }
  validate :validate_topic_is_unlocked
  validate :topic_id_not_invalid
  validate :topic_is_not_restricted, :on => :create
  validate :category_allows_replies, on: :create
  validate :validate_creator_is_not_limited, on: :create
  before_destroy :validate_topic_is_unlocked
  after_save :delete_topic_if_original_post
  after_update(:if => ->(rec) {rec.updater_id != rec.creator_id}) do |rec|
    ModAction.log(:forum_post_update, {forum_post_id: rec.id, forum_topic_id: rec.topic_id, user_id: rec.creator_id})
  end
  after_update(:if => ->(rec) {rec.saved_change_to_is_hidden?}) do |rec|
    ModAction.log(rec.is_hidden ? :forum_post_hide : :forum_post_unhide, {forum_post_id: rec.id, forum_topic_id: rec.topic_id, user_id: rec.creator_id})
  end
  after_destroy(:if => ->(rec) {rec.updater_id != rec.creator_id}) do |rec|
    ModAction.log(:forum_post_delete, {forum_post_id: rec.id, forum_topic_id: rec.topic_id, user_id: rec.creator_id})
  end

  attr_accessor :bypass_limits

  module SearchMethods
    def topic_title_matches(title)
      joins(:topic).merge(ForumTopic.search(title_matches: title))
    end

    def for_user(user_id)
      where("forum_posts.creator_id = ?", user_id)
    end

    def active
      where("(forum_posts.is_hidden = false or forum_posts.creator_id = ?)", CurrentUser.id)
    end

    def permitted
      q = joins(:topic)
      q = q.where("(forum_topics.is_hidden = false or forum_posts.creator_id = ?)", CurrentUser.id) unless CurrentUser.is_moderator?
      q
    end

    def search(params)
      q = super
      q = q.permitted

      q = q.where_user(:creator_id, :creator, params)

      if params[:topic_id].present?
        q = q.where("forum_posts.topic_id = ?", params[:topic_id].to_i)
      end

      if params[:topic_title_matches].present?
        q = q.topic_title_matches(params[:topic_title_matches])
      end

      q = q.attribute_matches(:body, params[:body_matches])

      if params[:topic_category_id].present?
        q = q.joins(:topic).where("forum_topics.category_id = ?", params[:topic_category_id].to_i)
      end

      q = q.attribute_matches(:is_hidden, params[:is_hidden])

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods

  def tag_change_request
    bulk_update_request || tag_alias || tag_implication
  end

  def votable?
    TagAlias.where(forum_post_id: id).exists? ||
      TagImplication.where(forum_post_id: id).exists? ||
      BulkUpdateRequest.where(forum_post_id: id).exists?
  end

  def validate_topic_is_unlocked
    return if CurrentUser.is_moderator?
    return if topic.nil?

    if topic.is_locked?
      errors.add(:topic, "is locked")
      throw :abort
    end
  end

  def validate_creator_is_not_limited
    return true if bypass_limits

    allowed = creator.can_forum_post_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def topic_id_not_invalid
    if topic_id && !topic
      errors.add(:base, "Topic ID is invalid")
      return false
    end
  end

  def topic_is_not_restricted
    if topic && !topic.visible?(creator)
      errors.add(:topic, "is restricted")
      return false
    end
  end

  def category_allows_replies
    if topic && !topic.can_reply?(creator)
      errors.add(:topic, "does not allow replies")
      return false
    end
  end

  def editable_by?(user)
    return true if user.is_admin?
    return false if was_warned?
    creator_id == user.id && visible?(user)
  end

  def visible?(user)
    user.is_moderator? || (topic.visible?(user) && (!is_hidden? || user.id == creator_id))
  end

  def can_hide?(user)
    return true if user.is_moderator?
    return false if was_warned?
    user.id == creator_id
  end

  def can_delete?(user)
    user.is_admin?
  end

  def update_topic_updated_at_on_create
    if topic
      # need to do this to bypass the topic's original post from getting touched
      ForumTopic.where(:id => topic.id).update_all(["updater_id = ?, response_count = response_count + 1, updated_at = ?", CurrentUser.id, Time.now])
      topic.response_count += 1
    end
  end

  def hide!
    update(is_hidden: true)
    update_topic_updated_at_on_hide
  end

  def unhide!
    update(is_hidden: false)
    update_topic_updated_at_on_hide
  end

  def update_topic_updated_at_on_hide
    max = ForumPost.where(:topic_id => topic.id, :is_hidden => false).order("updated_at desc").first
    if max
      ForumTopic.where(:id => topic.id).update_all(["updated_at = ?, updater_id = ?", max.updated_at, max.updater_id])
    end
  end

  def update_topic_updated_at_on_destroy
    max = ForumPost.where(:topic_id => topic.id, :is_hidden => false).order("updated_at desc").first
    if max
      ForumTopic.where(:id => topic.id).update_all(["response_count = response_count - 1, updated_at = ?, updater_id = ?", max.updated_at, max.updater_id])
      topic.response_count -= 1
    else
      ForumTopic.where(:id => topic.id).update_all("response_count = response_count - 1")
      topic.response_count -= 1
    end
  end

  def initialize_is_hidden
    self.is_hidden = false if is_hidden.nil?
  end

  def creator_name
    User.id_to_name(creator_id)
  end

  def updater_name
    User.id_to_name(updater_id)
  end

  def forum_topic_page
    ((ForumPost.where("topic_id = ? and created_at <= ?", topic_id, created_at).count) / Danbooru.config.posts_per_page.to_f).ceil
  end

  def is_original_post?(original_post_id = nil)
    if original_post_id
      return id == original_post_id
    else
      ForumPost.exists?(["id = ? and id = (select _.id from forum_posts _ where _.topic_id = ? order by _.id asc limit 1)", id, topic_id])
    end
  end

  def delete_topic_if_original_post
    if is_hidden? && is_original_post?
      topic.update_attribute(:is_hidden, true)
    end

    true
  end
end
