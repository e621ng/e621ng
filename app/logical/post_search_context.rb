# frozen_string_literal: true

class PostSearchContext
  attr_reader :post

  def initialize(params)
    tags = params[:q].presence || params[:tags].presence || ""
    # TODO: Determine if the following 2 lines are redundant & remove if so.
    tags += " rating:s" if CurrentUser.safe_mode?
    tags += " -status:deleted" if TagQuery.can_append_deleted_filter?(tags, at_any_level: true)
    pagination_mode = params[:seq] == "prev" ? "a" : "b"
    @post = Post.tag_match(tags).paginate("#{pagination_mode}#{params[:id]}", limit: 1).first || Post.find(params[:id])
  end
end
