class PostFavoritesController < ApplicationController
  before_action :member_only
  respond_to :html

  def index
    @users = ::Post.find(params[:post_id]).favorited_users
  end
end
