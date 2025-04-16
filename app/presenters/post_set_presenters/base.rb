# frozen_string_literal: true

module PostSetPresenters
  class Base
    def posts
      raise NotImplementedError
    end

    def post_previews_html(template, options = {})
      if posts.empty?
        return template.render("posts/blank")
      end

      previews = posts.map do |post|
        PostPresenter.preview(post, options.merge(tags: @post_set.tag_string))
      end
      template.safe_join(previews)
    end
  end
end
