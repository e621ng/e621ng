# frozen_string_literal: true

module PostSets
  class Post < PostSets::Base
    attr_reader :tag_array, :public_tag_array, :page, :limit, :random, :post_count

    def initialize(tags, page = 1, limit: nil, random: nil)
      super()
      tags ||= ""
      @public_tag_array = TagQuery.scan(tags)
      tags += " rating:s" if CurrentUser.safe_mode?
      tags += " -status:deleted" unless TagQuery.has_metatag?(tags, "status", "-status")
      @tag_array = TagQuery.scan(tags)
      @page = page
      @limit = limit || TagQuery.fetch_metatag(tag_array, "limit")
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

    def is_random?
      random || (TagQuery.fetch_metatag(tag_array, "order") == "random" && !TagQuery.has_metatag?(tag_array, "randseed"))
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
