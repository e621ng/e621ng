# frozen_string_literal: true

class Comment < ApplicationRecord
  RECENT_COUNT = 6
  include UserWarnable
  simple_versioning
  belongs_to_creator
  belongs_to_updater
  normalizes :body, with: ->(body) { body.gsub("\r\n", "\n") }
  validate :validate_post_exists, on: :create
  validate :validate_creator_is_not_limited, on: :create
  validate :post_not_comment_locked, on: :create
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
  belongs_to :warning_user, class_name: "User", optional: true
  has_many :votes, class_name: "CommentVote", dependent: :destroy

  scope :deleted, -> { where(is_hidden: true) }
  scope :undeleted, -> { where(is_hidden: false) }
  scope :stickied, -> { where(is_sticky: true) }

  module SearchMethods
    # NOTE: Ensure that logic here matches that in AccessMethods

    # ============================== #
    # ===== Visibility Methods ===== #
    # ============================== #

    # Authorization check: comments that the user has permission to see.
    def accessible(user = CurrentUser.user, bypass_user_settings: false)
      conditions = []
      arguments = []

      # 1. Visibility: not hidden or created by the user themselves
      if user.is_anonymous? || !(user.show_hidden_comments? || bypass_user_settings)
        conditions << "comments.is_hidden = false"
      elsif !user.is_staff?
        conditions << "(comments.is_hidden = false OR comments.creator_id = ?)"
        arguments << user.id
      end

      # 2. Disabled posts: non-staff cannot see any comments
      # TODO: Rethink this approach if we reach 100+ posts with comments disabled
      # As of November 2025, there are only 7 such posts.
      unless user.is_staff?
        disabled_post_ids = SearchMethods.comment_disabled_post_ids
        unless disabled_post_ids.empty?
          conditions << "comments.post_id NOT IN (?)"
          arguments << disabled_post_ids
        end
      end

      # If no conditions were added (staff with show_hidden_comments? enabled), return unfiltered relation.
      return all if conditions.empty?
      where(conditions.join(" AND "), *arguments)
    end

    # Score filtering: comments that meet the user's score threshold or are sticky.
    def above_threshold(user = CurrentUser.user)
      where("comments.is_sticky = true OR comments.score >= ?", user.comment_threshold)
    end

    # Score filtering: inverse of visible
    def below_threshold(user = CurrentUser.user)
      where("comments.is_sticky = false AND comments.score < ?", user.comment_threshold)
    end

    def self.comment_disabled_post_ids
      Rails.cache.fetch("comment_disabled_post_ids", expires_in: 1.hour) do
        Post.where(is_comment_disabled: true).pluck(:id)
      end
    end

    def self.clear_comment_disabled_cache
      Rails.cache.delete("comment_disabled_post_ids")
    end

    # ============================== #
    # ======= Search Methods ======= #
    # ============================== #

    def search(params)
      q = super.includes(:creator).includes(:updater).includes(:post)
      q = q.accessible(CurrentUser.user, bypass_user_settings: params[:id].present?)
      creator_filter_applied = false

      # Body search subquery: prevent timeouts on broad searches
      if params[:body_matches].present? && params[:body_matches].exclude?("*")
        search_term = params[:body_matches].strip.gsub(/\s+/, " ")

        if params[:advanced_search]
          # Advanced search using websearch_to_tsquery
          subquery = Comment
                     .unscoped
                     .select(:id)
                     .where("to_tsvector('english', body) @@ websearch_to_tsquery('english', ?)", search_term)
        else
          # Loose word search
          subquery = Comment
                     .unscoped
                     .select(:id)
                     .where("to_tsvector('english', body) @@ plainto_tsquery('english', ?)", search_term)
        end

        # Search by creator, if specified
        Comment.with_resolved_user_ids(:creator, params) do |user_ids|
          subquery = subquery.where(creator_id: user_ids)
          creator_filter_applied = true if user_ids.present?
        end

        subquery = subquery.order(created_at: :desc).limit(10_000)

        q = q.where("comments.id IN (#{subquery.to_sql})")
      else
        q = q.attribute_matches(:body, params[:body_matches])
      end

      if params[:post_id].present?
        q = q.where("post_id in (?)", params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      with_resolved_user_ids(:post_note_updater, params) do |user_ids|
        q = q.where(post_id: NoteVersion.select(:post_id).where(updater_id: user_ids))
      end

      q = q.where_user(:creator_id, :creator, params) unless creator_filter_applied

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

      q.where_user(:"posts.uploader_id", :poster, params) do |condition, _ids|
        condition = condition.joins(:post)
        # Force a better query plan by ordering by created_at
        condition.reorder("comments.created_at desc")
      end
    end

    def post_tags_match(query)
      where(post_id: Post.tag_match_sql(query).order(id: :desc).limit(300))
    end

    # ============================== #
    # ======= Other Methods ======== #
    # ============================== #

    def for_creator(user_id)
      user_id.present? ? where("creator_id = ?", user_id) : none
    end

    def recent
      reorder("comments.id desc").limit(RECENT_COUNT)
    end
  end

  module AccessMethods
    # NOTE: Ensure that logic here matches that in SearchMethods

    # Authorization check: user has permission to see this comment
    def is_accessible?(user = CurrentUser.user, bypass_user_settings: false)
      # 1. Visibility: not hidden or created by the user themselves
      if user.is_anonymous? || !(user.show_hidden_comments? || bypass_user_settings)
        return false if is_hidden?
      elsif !user.is_staff?
        return false if is_hidden? && creator_id != user.id
      end

      # 2. Disabled posts: non-staff cannot see any comments
      return false if !user.is_staff? && SearchMethods.comment_disabled_post_ids.include?(post_id)

      true
    end

    # Score filtering: comments that meet the user's score threshold or are sticky.
    def is_above_threshold?(user = CurrentUser.user)
      is_sticky? || score >= user.comment_threshold
    end

    # Score filtering: inverse of visible
    def is_below_threshold?(user = CurrentUser.user)
      !is_sticky? && score < user.comment_threshold
    end

    def can_reply?(user = CurrentUser.user)
      return false if is_sticky?
      return false if (post&.is_comment_locked? || post&.is_comment_disabled?) && !user.is_moderator?
      true
    end

    def can_edit?(user = CurrentUser.user)
      return true if user.is_admin?
      return false if (post&.is_comment_locked? || post&.is_comment_disabled?) && !user.is_moderator?
      return false if was_warned?
      creator_id == user.id
    end

    def can_hide?(user = CurrentUser.user)
      return true if user.is_moderator?
      return false if was_warned? || post&.is_comment_disabled?
      user.id == creator_id
    end
  end

  extend SearchMethods
  include AccessMethods

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

  def post_not_comment_locked
    return if CurrentUser.is_moderator?
    post = Post.find_by(id: post_id)
    return if post.blank?
    errors.add(:base, "Post has comments locked") if post.is_comment_locked?
    errors.add(:base, "Post has comments disabled") if post.is_comment_disabled?
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
      post.update_columns(last_commented_at: nil)
    else
      post.update_columns(last_commented_at: other_comments.first.created_at)
    end

    other_comments = other_comments.where("do_not_bump_post = FALSE")
    if other_comments.count == 0
      post.update_columns(last_comment_bumped_at: nil)
    else
      post.update_columns(last_comment_bumped_at: other_comments.first.created_at)
    end
    post.update_index
    true
  end

  def method_attributes
    super + %i[creator_name updater_name]
  end

  def hide!
    update(is_hidden: true)
  end

  def unhide!
    update(is_hidden: false)
  end
end
