class PostFavoritesController < ApplicationController
  before_action :member_only
  respond_to :html

  def index
    @post = Post.find(params[:post_id])
    query = User.includes(:user_status).joins(:favorites)
    unless CurrentUser.is_moderator?
      query = query.where("bit_prefs & :value != :value", {value: 2**User::BOOLEAN_ATTRIBUTES.find_index("enable_privacy_mode")}).or(query.where(favorites: {user_id: CurrentUser.id}))
    end
    query = query.where(favorites: {post_id: @post.id})
    query = query.order("users.name asc")
    @users = query.paginate(params[:page], limit: 75)
  end
end
