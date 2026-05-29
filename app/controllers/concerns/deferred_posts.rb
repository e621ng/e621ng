# frozen_string_literal: true

module DeferredPosts
  extend ActiveSupport::Concern

  def deferred_post_ids
    RequestStore[:deferred_post_ids] ||= Set.new
  end

  def deferred_posts
    posts = Post.includes(:uploader).where(id: deferred_post_ids.to_a).to_a
    unless CurrentUser.user&.is_anonymous?
      Post.preload_favorited_status!(posts, CurrentUser.id)
      Post.preload_vote_by!(posts, CurrentUser.id)
    end
    posts.each_with_object({}) { |p, hash| hash[p.id] = p.thumbnail_attributes }
  end
end
