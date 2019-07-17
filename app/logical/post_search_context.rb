class PostSearchContext
  extend Memoist
  attr_reader :id, :seq, :tags

  def initialize(params)
    @id = params[:id].to_i
    @seq = params[:seq]
    @tags = params[:q].presence || params[:tags].presence || "status:any"
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
