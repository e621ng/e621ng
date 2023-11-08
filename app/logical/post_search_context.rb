class PostSearchContext
  attr_reader :post

  def initialize(params)
    tags = params[:q].presence || params[:tags].presence || ""
    tags += " rating:s" if CurrentUser.safe_mode?
    tags += " -status:deleted" unless TagQuery.has_metatag?(tags, "status", "-status")
    pagination_mode = params[:seq] == "prev" ? "a" : "b"
    @post = Post.tag_match(tags).paginate("#{pagination_mode}#{params[:id]}", limit: 1).first || Post.find(params[:id])
  end
end
