class Comment < ApplicationRecord

  simple_versioning
  belongs_to_creator
  belongs_to_updater
  validate :validate_post_exists, :on => :create
  validate :validate_creator_is_not_limited, :on => :create
  validate :validate_comment_is_not_spam, on: :create
  validates :body, presence: { :message => "has no content" }
  validates :body, length: { minimum: 1, maximum: 10_000 }

  after_create :update_last_commented_at_on_create
  after_update(:if => ->(rec) {(!rec.is_hidden? || !rec.saved_change_to_is_hidden?) && CurrentUser.id != rec.creator_id}) do |rec|
    ModAction.log(:comment_update, {comment_id: rec.id, user_id: rec.creator_id})
  end
  after_save :update_last_commented_at_on_destroy, :if => ->(rec) {rec.is_hidden? && rec.saved_change_to_is_hidden?}
  after_destroy :update_last_commented_at_on_destroy
  after_save(:if => ->(rec) {rec.is_hidden? && rec.saved_change_to_is_hidden? && CurrentUser.id != rec.creator_id}) do |rec|
    ModAction.log(:comment_hide, {comment_id: rec.id, user_id: rec.creator_id})
  end


  user_status_counter :comment_count
  belongs_to :post, counter_cache: :comment_count
  has_many :votes, :class_name => "CommentVote", :dependent => :destroy

  module SearchMethods
    def recent
      reorder("comments.id desc").limit(6)
    end

    def hidden(user)
      if user.is_moderator?
        where("score < ? and is_sticky = false", user.comment_threshold)
      else
        where("(score < ? and is_sticky = false) or (is_hidden = true and creator_id != ?)", user.comment_threshold, user.id)
      end
    end

    def visible(user)
      if user.is_moderator?
        where("score >= ? or is_sticky = true", user.comment_threshold)
      else
        where("(score >= ? or is_sticky = true) and (is_hidden = false or creator_id = ?)", user.comment_threshold, user.id)
      end
    end

    def deleted
      where("comments.is_hidden = true")
    end

    def undeleted
      where("comments.is_hidden = false")
    end

    def post_tags_match(query)
      where(post_id: PostQueryBuilder.new(query).build.reorder(id: :desc).limit(300))
    end

    def poster_id(user_id)
      where(post_id: PostQueryBuilder.new("user_id:#{user_id}").build.reorder(id: :desc).limit(300))
    end

    def for_creator(user_id)
      user_id.present? ? where("creator_id = ?", user_id) : none
    end

    def for_creator_name(user_name)
      for_creator(User.name_to_id(user_name))
    end

    def search(params)
      q = super.includes(:creator).includes(:updater).includes(:post)

      q = q.attribute_matches(:body, params[:body_matches], index_column: :body_index)

      if params[:post_id].present?
        q = q.where("post_id in (?)", params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      if params[:creator_name].present?
        q = q.for_creator_name(params[:creator_name])
      end

      if params[:creator_id].present?
        q = q.for_creator(params[:creator_id].to_i)
      end

      if params[:poster_id].present?
        q = q.poster_id(params[:poster_id].to_i)
      end

      q = q.attribute_matches(:is_hidden, params[:is_hidden])
      q = q.attribute_matches(:is_sticky, params[:is_sticky])
      q = q.attribute_matches(:do_not_bump_post, params[:do_not_bump_post])

      case params[:order]
      when "post_id", "post_id_desc"
        q = q.order("comments.post_id DESC, comments.id DESC")
      when "score", "score_desc"
        q = q.order("comments.score DESC, comments.id DESC")
      when "updated_at", "updated_at_desc"
        q = q.order("comments.updated_at DESC")
      else
        q = q.apply_default_order(params)
      end

      q
    end
  end

  extend SearchMethods

  def validate_post_exists
    errors.add(:post, "must exist") unless Post.exists?(post_id)
  end

  def validate_creator_is_not_limited
    allowed = creator.can_comment_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def validate_comment_is_not_spam
    errors[:base] << "Failed to create comment" if SpamDetector.new(self).spam?
  end

  def update_last_commented_at_on_create
    post = Post.find(post_id)
    return unless post
    post.update_column(:last_commented_at, created_at)
    if Comment.where("post_id = ?", post_id).count <= Danbooru.config.comment_threshold && !do_not_bump_post?
      post.update_column(:last_comment_bumped_at, created_at)
    end
    post.update_index
    true
  end

  def update_last_commented_at_on_destroy
    post = Post.find(post_id)
    return unless post
    other_comments = Comment.where("post_id = ? and id <> ?", post_id, id).order("id DESC")
    if other_comments.count == 0
      post.update_columns(:last_commented_at => nil)
    else
      post.update_columns(:last_commented_at => other_comments.first.created_at)
    end

    other_comments = other_comments.where("do_not_bump_post = FALSE")
    if other_comments.count == 0
      post.update_columns(:last_comment_bumped_at => nil)
    else
      post.update_columns(:last_comment_bumped_at => other_comments.first.created_at)
    end
    post.update_index
    true
  end

  def below_threshold?(user = CurrentUser.user)
    score < user.comment_threshold
  end

  def editable_by?(user)
    creator_id == user.id || user.is_moderator?
  end

  def can_hide?(user)
    user.is_moderator? || user.id == creator_id
  end

  def visible_to?(user)
    return true if user.is_moderator?
    return true if is_hidden? == false
    creator_id == user.id # Can always see your own comments, even if hidden.
  end

  def should_see?(user)
    return true unless is_hidden?
    (creator_id == user.id) && user.show_hidden_comments?
  end

  def hidden_attributes
    super + [:body_index]
  end

  def method_attributes
    super + [:creator_name, :updater_name]
  end

  def hide!
    update(is_hidden: true)
  end

  def unhide!
    update(is_hidden: false)
  end

  def quoted_response
    DText.quote(body, creator_name)
  end
end
