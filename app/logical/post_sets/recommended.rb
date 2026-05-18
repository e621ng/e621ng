# frozen_string_literal: true

module PostSets
  class Recommended < PostSets::Base
    attr_reader :limit, :mode

    def initialize(post, limit: 6, mode: :artist)
      super()
      @original_post = post
      @limit = limit.to_i.clamp(1, 20)
      @original_post.categorized_tags # Preload categorized tags to avoid duplicate queries later

      @mode = mode
      if mode == :tags
        @no_results = post.tag_count <= 1 # only has tagme
      else
        @mode = :artist
        @no_results = post.known_artist_tags.empty?
      end
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
      @search_response ||= RecommendedQueryBuilder.new(@original_post, mode: @mode).search.limit(@limit)
    end
  end
end
