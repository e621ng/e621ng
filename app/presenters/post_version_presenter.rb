# frozen_string_literal: true

class PostVersionPresenter < Presenter
  delegate(:inline_tag_list_html, to: :tag_set_presenter)

  def initialize(post_version)
    super()
    @post_version = post_version
  end

  def tag_set_presenter
    @tag_set_presenter ||= TagSetPresenter.new(@post_version.original_tags)
  end
end
