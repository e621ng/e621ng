class Comment < ApplicationRecord
  include UserWarnable
  simple_versioning
  belongs_to_creator
  belongs_to_updater
  validate :validate_post_exists, on: :create
  validate :validate_creator_is_not_limited, on: :create
  validate :post_not_comment_disabled, on: :create
  validates :body, presence: { message: "has no content" }
  validates :body, length: { minimum: 1, maximum: Danbooru.config.comment_max_size }

  after_create :update_last_commented_at_on_create
  after_update(if: ->(rec) { !rec.saved_change_to_is_hidden? && CurrentUser.id != rec.creator_id }) do |rec|
    ModAction.log(:comment_update, { comment_id: rec.id, user_id: rec.creator_id })
  end
  after_destroy :update_last_commented_at_on_destroy
  after_destroy do |rec|
    ModAction.log(:comment_delete, { comment_id: rec.id, user_id: rec.creator_id })
  end
  after_save :update_last_commented_at_on_destroy, if: ->(rec) { rec.is_hidden? && rec.saved_change_to_is_hidden? }
  after_save(if: ->(rec) { rec.saved_change_to_is_hidden? && CurrentUser.id != rec.creator_id }) do |rec|
    action = rec.is_hidden? ? :comment_hide : :comment_unhide
    ModAction.log(action, { comment_id: rec.id, user_id: rec.creator_id })
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
      where(post_id: Post.tag_match_sql(query).order(id: :desc).limit(300))
    end

    def poster_id(user_id)
      joins(:post).where("posts.uploader_id = ?", user_id)
    end

    def for_creator(user_id)
      user_id.present? ? where("creator_id = ?", user_id) : none
    end

    def search(params)
      q = super.includes(:creator).includes(:updater).includes(:post)

      q = q.attribute_matches(:body, params[:body_matches])

      if params[:post_id].present?
        q = q.where("post_id in (?)", params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      q = q.where_user(:creator_id, :creator, params)

      if params[:ip_addr].present?
        q = q.where("creator_ip_addr <<= ?", params[:ip_addr])
      end

      q = q.attribute_matches(:is_hidden, params[:is_hidden])
      q = q.attribute_matches(:is_sticky, params[:is_sticky])
      q = q.attribute_matches(:do_not_bump_post, params[:do_not_bump_post])

      case params[:order]
      when "post_id", "post_id_desc"
        q = q.order("comments.post_id DESC, comments.created_at DESC")
      when "score", "score_desc"
        q = q.order("comments.score DESC, comments.created_at DESC")
      when "updated_at", "updated_at_desc"
        q = q.order("comments.updated_at DESC")
      else
        # Force a better query plan
        if %i[body_matches creator_name creator_id].any? { |key| params[key].present? }
          q = q.order(created_at: :desc)
        else
          q = q.apply_basic_order(params)
        end
      end

      if params[:poster_id].present?
        q = q.poster_id(params[:poster_id].to_i)
        # Force a better query plan by ordering by created_at
        q = q.reorder("comments.created_at desc")
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

  def post_not_comment_disabled
    errors.add(:base, "Post has comments disabled") if Post.find_by(id: post_id)&.is_comment_disabled
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
    return true if user.is_admin?
    return false if was_warned?
    creator_id == user.id
  end

  def can_hide?(user)
    return true if user.is_moderator?
    return false if was_warned?
    user.id == creator_id
  end

  def visible_to?(user)
    return true if user.is_moderator?
    return true if is_hidden? == false
    creator_id == user.id # Can always see your own comments, even if hidden.
  end

  def should_see?(user)
    return true if user.is_moderator?
    return true unless is_hidden?
    (creator_id == user.id) && user.show_hidden_comments?
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
end
