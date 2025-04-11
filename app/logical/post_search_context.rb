# frozen_string_literal: true

class PostSearchContext
  attr_reader :post

  def initialize(params)
    tags = params[:q].presence || params[:tags].presence || ""
    # Rails.logger.debug { "PSC tags before: #{tags}" }
    tags += " rating:s" if CurrentUser.safe_mode?
    tags += " -status:deleted" if TagQuery.can_append_deleted_filter?(tags, at_any_level: true)
    # Rails.logger.debug { "PSC tags after: #{tags}" }
    pagination_mode = params[:seq] == "prev" ? "a" : "b"
    @post = Post.tag_match(tags).paginate("#{pagination_mode}#{params[:id]}", limit: 1).first || Post.find(params[:id])
  end
end
