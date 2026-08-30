# frozen_string_literal: true

class PostDeletion < ApplicationRecord
  belongs_to :post
  belongs_to :deleter, class_name: "User"
  belongs_to :undeleter, class_name: "User", optional: true

  validates :reason, presence: true

  after_create :log_deletion_event

  scope :active, -> { where(is_undeleted: false) }
  scope :undeleted, -> { where(is_undeleted: true) }

  module SearchMethods
    def post_tags_match(query)
      where(post_id: Post.tag_match_sql(query))
    end

    def search(params)
      q = super

      q = q.attribute_matches(:reason, params[:reason_matches])
      q = q.where_user(:deleter_id, :deleter, params)

      with_resolved_user_ids(:uploader, params) do |user_ids|
        q = q.where(post_id: Post.select(:id).where(uploader_id: user_ids))
      end

      if params[:post_id].present?
        q = q.where(post_id: params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      if params[:ip_addr].present?
        q = q.where("creator_ip_addr <<= ?", params[:ip_addr])
      end

      q = if params[:undeleted_at].present?
            q.undeleted.attribute_matches(:undeleted_at, params[:undeleted_at])
          elsif params[:is_undeleted].present?
            params[:is_undeleted] == "any" ? q : q.attribute_matches(:is_undeleted, params[:is_undeleted])
          elsif params[:id].present? || params[:post_id].present?
            q
          else
            q.active
          end

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods

  def self.current_for(post)
    active.find_by(post_id: post.id)
  end

  def stamp_undeleted!(undeleter)
    update!(is_undeleted: true, undeleter: undeleter, undeleted_at: Time.current)
    PostEvent.add(post_id, undeleter, :undeleted)
  end

  def can_appeal?(user = CurrentUser.user)
    return false if is_undeleted?
    return false unless appealable_by?(user)
    return false if has_user_appealed?(user)
    true
  end

  def user_appeal(user)
    return nil unless appealable_by?(user)

    @user_appeal ||= {}
    unless @user_appeal.key?(user.id)
      # Multiple appeals used to be possible, so return the latest
      @user_appeal[user.id] = Appeal.where(
        creator_id: user.id,
        qtype: "post_deletion",
        disp_id: id,
      ).order(id: :desc).limit(1).first
    end
    @user_appeal[user.id]
  end

  def has_user_appealed?(user)
    user_appeal(user).present?
  end

  private

  # This is only a basic permission check, ignoring current deletion or appeal status.
  def appealable_by?(user)
    # Uploaders can appeal except for takedowns, verified artists can appeal deletions of their own posts
    (post.uploader_id == user.id && reason !~ /takedown #\d+/i) || post.linked_users.include?(user.id)
  end

  def log_deletion_event
    PostEvent.add(post_id, deleter, :deleted, { reason: reason })
  end
end
