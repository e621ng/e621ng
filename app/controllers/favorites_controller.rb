# frozen_string_literal: true

class FavoritesController < ApplicationController
  before_action :member_only, except: [:index]
  before_action :ensure_lockdown_disabled, except: %i[index]
  respond_to :json
  respond_to :html, only: [:index]
  skip_before_action :api_check

  def index
    if params[:tags]
      redirect_to(posts_path(tags: params[:tags]))
    else
      user_id = params[:user_id] || CurrentUser.user.id
      @user = User.find(user_id)

      if @user.hide_favorites?
        @post_set = PostSets::Post.new("limit:0")
      else
        @post_set = PostSets::Favorites.new(@user, params[:page], limit: params[:limit])
      end

      @posts = PostsDecorator.decorate_collection(@post_set.posts)
      respond_with(@posts) do |fmt|
        fmt.json do
          render json: @post_set.api_posts, root: "posts"
        end
      end
    end
  end

  def create
    @post = Post.find(params[:post_id])

    if @post.favorites_transfer_in_progress?
      render_expected_error(423, "Post favorites are being transferred, please try again later")
      return
    end

    FavoriteManager.add!(user: CurrentUser.user, post: @post)

    render json: { post_id: @post.id, favorite_count: @post.fav_count }
  rescue Favorite::Error, ActiveRecord::RecordInvalid => e
    render_expected_error(422, e.message)
  end

  def destroy
    @post = Post.find(params[:id])

    if @post.favorites_transfer_in_progress?
      render_expected_error(423, "Post favorites are being transferred, please try again later")
      return
    end

    FavoriteManager.remove!(user: CurrentUser.user, post: @post)

    render json: { post_id: @post.id, favorite_count: @post.fav_count }
  rescue Favorite::Error => e
    render_expected_error(422, e.message)
  end

  def ensure_lockdown_disabled
    render_expected_error(403, "Favorites are disabled") if Security::Lockdown.favorites_disabled? && !CurrentUser.is_staff?
  end
end
