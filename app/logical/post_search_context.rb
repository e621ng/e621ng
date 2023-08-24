class PostSearchContext
  extend Memoist
  attr_reader :id, :seq, :tags

  def initialize(params)
    @id = params[:id].to_i
    @seq = params[:seq]
    @tags = params[:q].presence || params[:tags].presence || ""
    @tags += " rating:s" if CurrentUser.safe_mode?
    @tags += " -status:deleted" unless TagQuery.has_metatag?(tags, "status", "-status")
  end

  def post_id
    if seq == "prev"
      Post.tag_match(tags).paginate("a#{id}", limit: 1).first.try(:id)
    else
      Post.tag_match(tags).paginate("b#{id}", limit: 1).first.try(:id)
    end
  end

  memoize :post_id
end
