module PostSets
  class Post < PostSets::Base
    MAX_PER_PAGE = 320
    attr_reader :tag_array, :public_tag_array, :page, :random, :post_count

    def initialize(tags, page = 1, per_page = nil, random: nil)
      tags ||= ""
      @public_tag_array = TagQuery.scan(tags)
      tags += " rating:s" if CurrentUser.safe_mode?
      tags += " -status:deleted" unless TagQuery.has_metatag?(tags, "status", "-status")
      @tag_array = TagQuery.scan(tags)
      @page = page
      @per_page = per_page
      @random = random.present?
    end

    def tag_string
      @tag_string ||= tag_array.uniq.join(" ")
    end

    def public_tag_string
      @public_tag_string ||= public_tag_array.uniq.join(" ")
    end

    def ad_tag_string
      TagQuery.ad_tag_string(public_tag_array)
    end

    def humanized_tag_string
      public_tag_array.slice(0, 25).join(" ").tr("_", " ")
    end

    def has_explicit?
      !CurrentUser.safe_mode?
    end

    def hidden_posts
      @hidden_posts ||= posts.select { |p| !p.visible? }
    end

    def login_blocked_posts
      @login_blocked ||= posts.select { |p| p.loginblocked? }
    end

    def safe_posts
      @safe_posts ||= posts.select { |p| p.safeblocked? && !p.deleteblocked? }
    end

    def per_page
      (@per_page || TagQuery.fetch_metatag(tag_array, "limit") || CurrentUser.user.per_page).to_i.clamp(0, MAX_PER_PAGE)
    end

    def is_random?
      random || (TagQuery.fetch_metatag(tag_array, "order") == "random" && !TagQuery.has_metatag?(tag_array, "randseed"))
    end

    def posts
      @posts ||= begin
        temp = ::Post.tag_match(tag_string).paginate(page, limit: per_page, includes: [:uploader])

        @post_count = temp.total_count
        temp
      end
    end

    def api_posts
      _posts = posts
      fill_children(_posts)
      fill_tag_types(_posts)
      _posts
    end

    def current_page
      [page.to_i, 1].max
    end

    def presenter
      @presenter ||= ::PostSetPresenters::Post.new(self)
    end
  end
end
