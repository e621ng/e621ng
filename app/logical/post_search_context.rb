# frozen_string_literal: true

class PostSearchContext
  attr_reader :post

  def initialize(params)
    tags = params[:q].presence || params[:tags].presence || ""
    pagination_mode = -"#{params[:seq] == 'prev' ? 'a' : 'b'}#{params[:id]}"
    @post = Post.tag_match(tags).paginate(pagination_mode, limit: 1).first || Post.find(params[:id])
  end
end
