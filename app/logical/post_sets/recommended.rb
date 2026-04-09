# frozen_string_literal: true

module PostSets
  class Recommended < PostSets::Base
    attr_reader :limit

    def initialize(post, limit: 6)
      super()
      @original_post = post
      @limit = limit.to_i.clamp(1, 20)
      @original_post.categorized_tags # Preload categorized tags to avoid duplicate queries later
      @no_results = post.known_artist_tags.empty?
    end

    def post_ids
      @post_ids ||= posts.map(&:id)
    end

    def posts
      @posts ||= @no_results ? [] : RecommendedQueryBuilder.new(@original_post).search.limit(@limit).to_a
    end
  end
end
