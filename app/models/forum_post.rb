class ForumPost < ApplicationRecord

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
  validates :body, length: { minimum: 1, maximum: 50_000 }
  validate :validate_topic_is_unlocked
  validate :topic_id_not_invalid
  validate :validate_post_is_not_spam, on: :create
  validate :topic_is_not_restricted, :on => :create
  validate :category_allows_replies, on: :create
  validate :validate_creator_is_not_limited, on: :create
  before_destroy :validate_topic_is_unlocked
  after_save :delete_topic_if_original_post
  after_update(:if => ->(rec) {rec.updater_id != rec.creator_id}) do |rec|
    ModAction.log(:forum_post_update, {forum_post_id: rec.id, forum_topic_id: rec.topic_id, user_id: rec.creator_id})
  end
  after_destroy(:if => ->(rec) {rec.updater_id != rec.creator_id}) do |rec|
    ModAction.log(:forum_post_delete, {forum_post_id: rec.id, forum_topic_id: rec.topic_id, user_id: rec.creator_id})
  end

  module SearchMethods
    def topic_title_matches(title)
      joins(:topic).merge(ForumTopic.search(title_matches: title))
    end

    def for_user(user_id)
      where("forum_posts.creator_id = ?", user_id)
    end

    def creator_name(name)
      where("forum_posts.creator_id = (select _.id from users _ where lower(_.name) = ?)", name.mb_chars.downcase)
    end

    def active
      where("(forum_posts.is_hidden = false or forum_posts.creator_id = ?)", CurrentUser.id)
    end

    def permitted
      q = joins(:topic).where("forum_topics.min_level <= ?", CurrentUser.level)
      q = q.where("(forum_topics.is_hidden = false or forum_posts.creator_id = ?)", CurrentUser.id) unless CurrentUser.is_moderator?
      q
    end

    def search(params)
      q = super
      q = q.permitted

      if params[:creator_id].present?
        q = q.where("forum_posts.creator_id = ?", params[:creator_id].to_i)
      end

      if params[:topic_id].present?
        q = q.where("forum_posts.topic_id = ?", params[:topic_id].to_i)
      end

      if params[:topic_title_matches].present?
        q = q.topic_title_matches(params[:topic_title_matches])
      end

      q = q.attribute_matches(:body, params[:body_matches], index_column: :text_index)

      if params[:creator_name].present?
        q = q.creator_name(params[:creator_name].tr(" ", "_"))
      end

      if params[:topic_category_id].present?
        q = q.joins(:topic).where("forum_topics.category_id = ?", params[:topic_category_id].to_i)
      end

      q = q.attribute_matches(:is_hidden, params[:is_hidden])

      q.apply_default_order(params)
    end
  end

  module ApiMethods
    def as_json(options = {})
      if CurrentUser.user.level < topic.min_level
        options[:only] = [:id]
      end

      super(options)
    end

    def to_xml(options = {})
      if CurrentUser.user.level < topic.min_level
        options[:only] = [:id]
      end

      super(options)
    end

    def hidden_attributes
      super + [:text_index]
    end
  end

  extend SearchMethods
  include ApiMethods

  def self.new_reply(params)
    if params[:topic_id]
      new(:topic_id => params[:topic_id])
    elsif params[:post_id]
      forum_post = ForumPost.find(params[:post_id])
      forum_post.build_response
    else
      new
    end
  end

  def tag_change_request
    bulk_update_request || tag_alias || tag_implication
  end

  def votable?
    TagAlias.where(forum_post_id: id).exists? ||
      TagImplication.where(forum_post_id: id).exists? ||
      BulkUpdateRequest.where(forum_post_id: id).exists?
  end

  def voted?(user, score)
    votes.where(creator_id: user.id, score: score).exists?
  end

  def validate_post_is_not_spam
    errors[:base] << "Failed to create forum post" if SpamDetector.new(self, user_ip: CurrentUser.ip_addr).spam?
  end

  def validate_topic_is_unlocked
    return if CurrentUser.is_moderator?
    return if topic.nil?

    if topic.is_locked?
      errors[:topic] << "is locked"
      throw :abort
    end
  end

  def validate_creator_is_not_limited
    allowed = creator.can_comment_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def topic_id_not_invalid
    if topic_id && !topic
      errors[:base] << "Topic ID is invalid"
      return false
    end
  end

  def topic_is_not_restricted
    if topic && !topic.visible?(creator)
      errors[:topic] << "is restricted"
      return false
    end
  end

  def category_allows_replies
    if topic && !topic.can_reply?(creator)
      errors[:topic] << "does not allow replies"
      return false
    end
  end

  def editable_by?(user)
    (creator_id == user.id || user.is_moderator?) && visible?(user)
  end

  def visible?(user)
    user.is_moderator? || (topic.visible?(user) && (!is_hidden? || user.id == creator_id))
  end

  def can_hide?(user)
    user.is_moderator? || user.id == creator_id
  end

  def can_delete?(user)
    user.is_moderator?
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

  def quoted_response
    DText.quote(body, creator_name)
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

  def build_response
    dup.tap do |x|
      x.body = x.quoted_response
    end
  end
end
