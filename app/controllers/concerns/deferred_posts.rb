# frozen_string_literal: true

module DeferredPosts
  extend ActiveSupport::Concern

  def deferred_post_ids
    RequestStore[:deferred_post_ids] ||= Set.new
  end

  def deferred_posts
    Post.includes(:uploader).where(id: deferred_post_ids.to_a).find_each.reduce({}) do |post_hash, p|
      post_hash[p.id] = p.thumbnail_attributes
      post_hash
    end
  end
end
