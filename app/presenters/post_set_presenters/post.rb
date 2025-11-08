# frozen_string_literal: true

module PostSetPresenters
  class Post < Base
    attr_accessor :post_set

    delegate :posts, to: :post_set

    def initialize(post_set)
      super()
      @post_set = post_set
    end

    def tag_set_presenter
      @tag_set_presenter ||= TagSetPresenter.new(related_tags, list_of: "all")
    end

    def related_tags
      RelatedTagCalculator.calculate_from_posts_to_array(post_set.posts).map(&:first)
    end
  end
end
