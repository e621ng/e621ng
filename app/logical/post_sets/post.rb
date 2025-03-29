# frozen_string_literal: true

module PostSets
  # `initialize(tags, page = 1, limit: nil, random: nil)`:
  # * `tags`
  # * `page` [`1`]
  # * `limit` [`nil`]
  # * `random` [`nil`]
  class Post < PostSets::Base
    attr_reader :tag_array, :public_tag_array, :page, :limit, :random, :post_count

    def initialize(tags, page = 1, limit: nil, random: nil)
      super()
      tags ||= ""
      @public_tag_array = TagQuery.scan_search(tags, error_on_depth_exceeded: true)
      @tag_array = @public_tag_array.dup
      @tag_array << "rating:s" if CurrentUser.safe_mode?
      @tag_array << "-status:deleted" if TagQuery.should_hide_deleted_posts?(tags, at_any_level: true)
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

    def public_tag_string
      @public_tag_string ||= TagQuery.scan_recursive(
        public_tag_array.uniq.join(" "),
        strip_duplicates_at_level: true,
        delimit_groups: true,
        flatten: true,
        strip_prefixes: false,
        sort_at_level: false,
        normalize_at_level: false,
      ).join(" ")
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

    def is_random?
      random || (TagQuery.fetch_metatag(tag_array, "order", at_any_level: false) == "random" && !TagQuery.has_metatag?(tag_array, "randseed", at_any_level: false))
    end

    def posts
      @posts ||= begin
        temp = ::Post.tag_match(tag_string).paginate_posts(page, limit: limit, includes: [:uploader])

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

    def related_tags
      @related_tags ||= begin
        tag_array = RelatedTagCalculator.calculate_from_posts_to_array(posts).map(&:first)
        tag_data = Tag.where(name: tag_array).select(:name, :post_count, :category).index_by(&:name)

        tag_array.map do |name|
          tag_data[name] || Tag.new(name: name).freeze
        end
      end
    end
  end
end
