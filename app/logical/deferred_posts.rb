class DeferredPosts
  KEY = :deferred_posts

  def self.add(post_id)
    raise ArgumentError.new "post id must be a number" if post_id.nil? || !post_id.respond_to?(:to_id)
    posts = RequestStore[KEY] || []
    posts << post_id.to_i
    RequestStore[KEY] = posts
  end

  def self.remove(post_id)
    posts = RequestStore[KEY] || []
    RequestStore[KEY] = posts - [post_id]
  end

  def self.clear
    RequestStore[KEY] = []
  end

  def self.dump
    post_ids = RequestStore[KEY] || []
    post_ids.uniq!
    post_hash = {}
    posts = Post.where(id: post_ids)
    posts.find_each do |p|
      post_hash[p.id] = p.minimal_attributes
    end
    post_hash
  end
end