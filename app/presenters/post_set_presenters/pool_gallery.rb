module PostSetPresenters
  class PoolGallery < Base
    attr_accessor :post_set
    delegate :pools, :to => :post_set

    def initialize(post_set)
      @post_set = post_set
    end

    def post_previews_html(template)
      html = ""

      if pools.empty?
        return template.render("posts/blank")
      end

      pools.each do |pool|
        if pool.cover_post_id
          post = ::Post.find(pool.cover_post_id)
          html << PostPresenter.preview(post, inline: true, link_target: pool, pool: pool, show_deleted: true, thumbnail_blacklisted: true)
          html << "\n"
        end
      end

      html.html_safe
    end
  end
end
