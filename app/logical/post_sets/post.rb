module PostSets
  class Post < PostSets::Base
    MAX_PER_PAGE = 320
    attr_reader :tag_array, :public_tag_array, :page, :random, :post_count, :format

    def initialize(tags, page = 1, per_page = nil, options = {})
      tags ||= ''
      @public_tag_array = Tag.scan_query(tags)
      tags += " rating:s" if CurrentUser.safe_mode?
      tags += " -status:deleted" if !Tag.has_metatag?(tags, "status", "-status")
      @tag_array = Tag.scan_query(tags)
      @page = page
      @per_page = per_page
      @random = options[:random].present?
      @format = options[:format] || "html"
    end

    def tag_string
      @tag_string ||= tag_array.uniq.join(" ")
    end

    def public_tag_string
      @public_tag_string ||= public_tag_array.uniq.join(" ")
    end

    def humanized_tag_string
      public_tag_array.slice(0, 25).join(" ").tr("_", " ")
    end

    def unordered_tag_array
      tag_array.reject {|tag| tag =~ /\Aorder:/i }
    end

    def tag
      return nil if !is_single_tag?
      return nil if is_metatag_only?
      @tag ||= Tag.find_by(name: Tag.normalize_name(tag_string))
    end

    def is_metatag_only?
      Tag.is_metatag?(Tag.normalize_name(tag_string))
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
      (@per_page || Tag.has_metatag?(tag_array, :limit) || CurrentUser.user.per_page).to_i.clamp(0, MAX_PER_PAGE)
    end

    def is_random?
      random || (Tag.has_metatag?(tag_array, :order) == "random" && !Tag.has_metatag?(tag_array, :randseed))
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

    def hide_from_crawler?
      !is_empty_tag?
    end

    def is_single_tag?
      tag_array.size == 1
    end

    def is_simple_tag?
      Tag.is_simple_tag?(tag_string)
    end

    def is_empty_tag?
      tag_array.size == 0
    end

    def is_pattern_search?
      is_single_tag? && tag_string =~ /\*/ && !tag_array.any? {|x| x =~ /^-?source:.+/}
    end

    def current_page
      [page.to_i, 1].max
    end

    def presenter
      @presenter ||= ::PostSetPresenters::Post.new(self)
    end
  end
end
