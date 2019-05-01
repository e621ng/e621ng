module DeferredPosts
  extend ActiveSupport::Concern

  def deferred_post_ids
    @post_ids_set ||= Set.new
  end

  def deferred_posts
    Post.where(id: deferred_post_ids.to_a).find_each.reduce({}) do |post_hash, p|
      post_hash[p.id] = p.minimal_attributes
      post_hash
    end
  end
end