# frozen_string_literal: true

class PostFavoritesController < ApplicationController
  respond_to :html

  def index
    @post = Post.find(params[:post_id])

    # Base query: users who favorited this post
    query = User.includes(:user_status)
                .joins(favorites: {}).where(favorites: { post_id: @post.id })

    # Privacy filter for non-moderators
    unless CurrentUser.is_moderator?
      privacy_flag = User.flag_value_for("enable_privacy_mode")
      query = query.where("(users.bit_prefs & ?) = 0", privacy_flag)
    end

    query = query.order("users.name asc")

    paginate_options = {}
    paginate_options[:limit] = params[:limit].to_i.clamp(1, 100) if params[:limit].present?
    paginate_options[:total_count] = @post.fav_count if @post.fav_count > 1000

    @users = query.paginate(params[:page], paginate_options)
  end
end
