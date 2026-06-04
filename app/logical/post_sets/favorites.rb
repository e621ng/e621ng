# frozen_string_literal: true

module PostSets
  class Favorites < PostSets::Base
    attr_reader :page, :limit

    def initialize(user, page, limit:, post_count: nil)
      super()
      @user = user
      @page = page
      @limit = limit
      @post_count = post_count
    end

    def tag_string
      "fav:#{@user.name}"
    end

    def posts
      @post_count ||= ::Post.tag_match("fav:#{@user.name} status:any").count_only
      @posts ||= begin
        favs = ::Favorite.for_user(@user.id)
                         .includes(post: :uploader)
                         .order(id: :desc)
                         .paginate_posts(page, total_count: @post_count, limit: @limit)
        favorites = favs.records
        new_opts = {
          pagination_mode: favs.pagination_mode,
          records_per_page: favs.records_per_page,
          total_count: @post_count,
          current_page: favs.current_page,
          sequential_first_id: favorites.first&.id,
          sequential_last_id: favorites.last&.id,
          is_first_page: favs.is_first_page?,
          is_last_page: favs.is_last_page?,
          finalized: true,
        }
        ::Danbooru::Paginator::PaginatedArray.new(favorites.map(&:post), new_opts)
      end
    end

    def has_explicit?
      !CurrentUser.safe_mode?
    end

    def hidden_posts
      @hidden_posts ||= posts.reject(&:visible?)
    end

    def login_blocked_posts
      @login_blocked_posts ||= posts.select(&:loginblocked?)
    end

    def safe_posts
      @safe_posts ||= posts.select { |p| p.safeblocked? && !p.deleteblocked? }
    end

    def api_posts
      result = posts
      fill_children(result)
      fill_tag_types(result)
      result
    end

    def tag_array
      []
    end

    def presenter
      ::PostSetPresenters::Post.new(self)
    end

    def is_random?
      false
    end
  end
end
