require_relative '../danbooru/paginator/elasticsearch_extensions'
module PostSets
  class Favorites < PostSets::Base
    attr_reader :page, :limit

    def initialize(user, page)
      @user = user
      @page = page
      @limit = CurrentUser.per_page
    end

    def public_tag_string
      "fav:#{@user.name}"
    end

    def current_page
      [page.to_i, 1].max
    end

    def posts
      @post_count ||= ::Post.tag_match("fav:#{@user.name} status:any").count_only
      @posts ||= begin
                   favs = ::Favorite.for_user(@user.id).includes(:post).order(created_at: :desc).paginate(page, count: @post_count, limit: @limit)
                   new_opts = {mode: :numbered, per_page: favs.records_per_page, total: @post_count, current_page: current_page}
                   ::Danbooru::Paginator::PaginatedArray.new(favs.map {|f| f.post},
                                                           new_opts
                                                           )
                 end
    end

    def is_pattern_search?
      false
    end

    def is_empty_tag?
      false
    end

    def unordered_tag_array
      []
    end

    def tag_array
      []
    end

    def presenter
      ::PostSetPresenters::Post.new(self)
    end
  end
end
