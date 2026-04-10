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
      @post_ids ||= @no_results ? [] : search_response.ids
    end

    def posts
      @posts ||= if @no_results
                   []
                 else
                   ids = post_ids
                   ::Post.where(id: ids).sort_by { |p| ids.index(p.id) }
                 end
    end

    def search_response
      @search_response ||= RecommendedQueryBuilder.new(@original_post).search.limit(@limit)
    end
  end
end
