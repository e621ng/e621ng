# frozen_string_literal: true

module PostSetPresenters
  class Post < Base
    attr_accessor :post_set
    delegate :posts, to: :post_set
    delegate :post_index_sidebar_tag_list_html, to: :tag_set_presenter

    def initialize(post_set)
      @post_set = post_set
    end

    def tag_set_presenter
      @tag_set_presenter ||= TagSetPresenter.new(related_tags)
    end

    def post_previews_html(template, options = {})
      super(template, options.merge(show_cropped: true))
    end

    def related_tags
      RelatedTagCalculator.calculate_from_posts_to_array(post_set.posts).map(&:first)
    end
  end
end
