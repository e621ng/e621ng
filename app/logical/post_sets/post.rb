# frozen_string_literal: true

module PostSets
  # `initialize(tags, page = 1, limit: nil, random: nil)`:
  # * `tags`
  # * `page` [`1`]
  # * `limit` [`nil`]
  # * `random` [`nil`]
  class Post < PostSets::Base
    attr_reader :tag_array, :page, :limit, :random, :post_count

    def initialize(tags, page = 1, limit: nil, random: nil)
      super()
      tags ||= ""
      @tag_array = TagQuery.scan_search(tags, error_on_depth_exceeded: true)
      @page = page
      # limit should have been hoisted by scan_search
      @limit = limit || TagQuery.fetch_metatag(tag_array, "limit", at_any_level: false)
      @random = random.present?
    end

    def tag_string
      @tag_string ||= TagQuery.scan_recursive(
        tag_array.uniq.join(" "),
        strip_duplicates_at_level: true,
        delimit_groups: true,
        flatten: true,
        strip_prefixes: false,
        sort_at_level: false,
        normalize_at_level: false,
      ).join(" ")
    end

    def ad_tag_string
      TagQuery.ad_tag_string(tag_array)
    end

    def humanized_tag_string
      tag_array.slice(0, 25).join(" ").tr("_", " ")
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

    def is_random?
      return true if random
      mts = TagQuery.fetch_metatags(tag_array, "order", "randseed")
      !!(mts["order"]&.include?("random") && !mts.key?("randseed"))
    end

    def posts
      @posts ||= begin
        temp = ::Post.tag_match(tag_string).paginate_posts(page, limit: limit, includes: [:uploader])

        @post_count = temp.total_count
        temp
      end
    end

    def api_posts
      posts_dup = posts
      fill_children(posts_dup)
      fill_tag_types(posts_dup)
      posts_dup
    end

    def current_page
      [page.to_i, 1].max
    end

    def presenter
      @presenter ||= ::PostSetPresenters::Post.new(self)
    end
  end
end
