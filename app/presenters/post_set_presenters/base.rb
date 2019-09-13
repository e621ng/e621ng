module PostSetPresenters
  class Base
    def posts
      raise NotImplementedError
    end

    def post_previews_html(template, options = {})
      html = ""

      if posts.empty?
        return template.render("posts/blank")
      end

      posts.each do |post|
        html << PostPresenter.preview(post, options.merge(:tags => @post_set.public_tag_string, :raw => @post_set.raw))
        html << "\n"
      end

      html.html_safe
    end
  end
end
