module PostSets
  class Pool < PostSets::Base
    attr_reader :pool, :page

    def initialize(pool, page = 1)
      @pool = pool
      @page = page
    end

    def offset
      (current_page - 1) * limit
    end

    def limit
      CurrentUser.user.per_page
    end

    def tag_array
      ["pool:#{pool.id}"]
    end

    def posts
      @posts ||= begin
        posts = pool.posts(offset: offset, limit: limit)
        options = { pagination_mode: :numbered, records_per_page: limit, total_count: pool.post_count, current_page: current_page }
        Danbooru::Paginator::PaginatedArray.new(posts, options)
      end
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

    def current_page
      [page.to_i, 1].max
    end
  end
end
