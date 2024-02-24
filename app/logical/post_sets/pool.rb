module PostSets
  class Pool < PostSets::Base
    attr_reader :pool, :page

    def initialize(pool, page = 1)
      @pool = pool
      @page = page
    end

    def limit
      CurrentUser.user.per_page
    end

    def tag_array
      ["pool:#{pool.id}"]
    end

    def posts
      @posts ||= pool.posts.paginate(page, limit: limit, total_count: pool.post_ids.count)
    end

    def tag_string
      tag_array.join("")
    end

    def humanized_tag_string
      "pool:#{pool.pretty_name}"
    end

    def presenter
      @presenter ||= PostSetPresenters::Pool.new(self)
    end
  end
end
