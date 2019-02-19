module PostSets
  class Post < PostSets::Base
    MAX_PER_PAGE = 200
    attr_reader :tag_array, :page, :raw, :random, :post_count, :format, :read_only

    def initialize(tags, page = 1, per_page = nil, options = {})
      @tag_array = Tag.scan_query(tags)
      @page = page
      @per_page = per_page
      @raw = options[:raw].present?
      @random = options[:random].present?
      @format = options[:format] || "html"
      @read_only = options[:read_only]
    end

    def tag_string
      @tag_string ||= tag_array.uniq.join(" ")
    end

    def humanized_tag_string
      tag_array.slice(0, 25).join(" ").tr("_", " ")
    end

    def unordered_tag_array
      tag_array.reject {|tag| tag =~ /\Aorder:/i }
    end

    def has_wiki?
      is_single_tag? && ::WikiPage.titled(tag_string).exists? && wiki_page.visible?
    end

    def has_wiki_text?
      has_wiki? && wiki_page.body.present?
    end

    def has_blank_wiki?
      is_simple_tag? && !has_wiki?
    end

    def wiki_page
      if is_single_tag?
        ::WikiPage.titled(tag_string).first
      else
        nil
      end
    end

    def tag
      return nil if !is_single_tag?
      @tag ||= Tag.find_by(name: Tag.normalize_name(tag_string))
    end

    def has_artist?
      is_single_tag? && artist.present? && artist.visible?
    end

    def artist
      @artist ||= ::Artist.named(tag_string).active.first
    end

    def pool_name
      @pool_name ||= Tag.has_metatag?(tag_array, :ordpool, :pool)
    end

    def has_pool?
      is_single_tag? && pool_name && pool
    end

    def pool
      ::Pool.find_by_name(pool_name)
    end

    def post_set_name
      @post_set_name ||= Tag.has_metatag?(tag_array, :set)
    end

    def has_post_set?
      is_single_tag? && post_set_name && post_set
    end

    def post_set
      ::PostSet.find_by_shortname(post_set_name)
    end

    def has_deleted?
      tag_string !~ /status/ && ::Post.tag_match("#{tag_string} status:deleted").where("true /* PostSets::Post#has_deleted */").exists?
    end

    def has_explicit?
      posts.any? {|x| x.rating == "e"}
    end

    def hidden_posts
      posts.select { |p| !p.visible? }
    end

    def deleted_posts
      posts.select { |p| p.deleteblocked? }
    end

    def safe_posts
      posts.select { |p| p.safeblocked? && !p.deleteblocked? }
    end

    def per_page
      (@per_page || Tag.has_metatag?(tag_array, :limit) || CurrentUser.user.per_page).to_i.clamp(0, MAX_PER_PAGE)
    end

    def is_random?
      random || Tag.has_metatag?(tag_array, :order) == "random"
    end

    def use_sequential_paginator?
      unknown_post_count? && !CurrentUser.is_gold?
    end

    def get_post_count
      if %w(json atom xml).include?(format.downcase)
        # no need to get counts for formats that don't use a paginator
        return Danbooru.config.blank_tag_search_fast_count
      else
        ::Post.fast_count(tag_string)
      end
    end

    def get_random_posts
      posts = ::Post.tag_match(tag_string).records
      per_page.times.inject([]) do |all, x|
        all << posts.random
      end.compact.uniq
    end

    def posts
      #if tag_array.any? {|x| x =~ /^-?source:.*\*.*pixiv/} && !CurrentUser.user.is_builder?
      #  raise SearchError.new("Your search took too long to execute and was canceled")
      #end

      @posts ||= begin
        if is_random?
          temp = get_random_posts
        elsif raw
          temp = ::Post.raw_tag_match(tag_string).order("posts.id DESC").where("true /* PostSets::Post#posts:1 */").paginate(page, :count => post_count, :limit => per_page)
        else
          # TODO: .records is not 1:1 with ActiveRecord, so we lose our extension methods if we turn this into an enumerator
          # It would make this much faster if this was materialized into a typed collection with the required extensions for pagination
          # without trying to load it from the DB each time.
          temp = ::Post.tag_match(tag_string, read_only).paginate(page, :count => post_count, :limit => per_page).records
        end

        @post_count = temp.total_count
        temp
      end
    end

    def unknown_post_count?
      post_count == Danbooru.config.blank_tag_search_fast_count
    end

    def hide_from_crawler?
      !is_simple_tag? || page.to_i > 1
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

    def is_saved_search?
      tag_string =~ /search:/
    end

    def presenter
      @presenter ||= ::PostSetPresenters::Post.new(self)
    end

    def best_post
      # be smarter about this in the future
      posts.max {|a, b| a.fav_count <=> b.fav_count}
    end
  end
end
