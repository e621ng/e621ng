# frozen_string_literal: true

module PostSets
  class Recommended < PostSets::Base
    attr_reader :tag_array, :limit

    def initialize(post, limit: 6)
      super()
      @original_post = post
      @limit = limit.to_i.clamp(1, 20)

      tags = post.known_artist_tags.sort_by(&:name).first(10).map { |t| "~#{t.name}" }
      if tags.empty?
        @no_results = true
        @tag_array = []
        return
      end

      tags << "-id:#{post.id}"
      tags << "-parent:#{post.id}"
      tags << "-child:#{post.id}"
      tags << "order:random"
      tags << "rating:safe" if CurrentUser.safe_mode?
      tags << "randseed:#{post.id}"

      @tag_array = TagQuery.scan_search(tags.join(" "), error_on_depth_exceeded: true)
    end

    def tag_string
      @tag_string ||= @tag_array.join(" ")
    end

    def post_ids
      @post_ids ||= posts.map(&:id)
    end

    def posts
      @posts ||= @no_results ? [] : ::Post.tag_match(tag_string).limit(@limit).to_a
    end
  end
end
