# frozen_string_literal: true

module PostSets
  class Recommended < PostSets::Base
    attr_reader :tag_array, :page, :limit, :post_count

    def initialize(post, page = 1, limit: nil)
      super()
      @original_post = post

      tags = post.known_artist_tags.map { |t| "~#{t.name}" }
      tags << "-id:#{post.id}"
      tags << "-parent:#{post.id}"
      tags << "-child:#{post.id}"
      tags << "order:random"
      tags << "rating:safe" if CurrentUser.safe_mode?
      tags << "randseed:#{post.id}"

      @tag_array = TagQuery.scan_search(tags.join(" "), error_on_depth_exceeded: true)
      @page = [page.to_i, 1].max
      @limit = limit
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

    def humanized_tag_string
      tag_array.slice(0, 25).join(" ").tr("_", " ")
    end

    def post_ids
      @post_ids ||= ::Post.tag_match(tag_string).paginate_posts(page, limit: limit).pluck(:id)
    end

    def posts
      @posts ||= begin
        temp = ::Post.tag_match(tag_string).paginate_posts(page, limit: limit, includes: [:uploader])

        @post_count = temp.total_count
        temp
      end
    end
  end
end
