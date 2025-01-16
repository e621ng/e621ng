# frozen_string_literal: true

class FavoritesController < ApplicationController
  before_action :member_only, except: [:index]
  before_action :ensure_lockdown_disabled, except: %i[index]
  respond_to :html, :json
  skip_before_action :api_check

  def index
    if params[:tags]
      redirect_to(posts_path(:tags => params[:tags]))
    else
      user_id = params[:user_id] || CurrentUser.user.id
      @user = User.find(user_id)

      if @user.hide_favorites?
        raise Favorite::HiddenError
      end

      @favorite_set = PostSets::Favorites.new(@user, params[:page], limit: params[:limit])
      respond_with(@favorite_set.posts) do |fmt|
        fmt.json do
          render json: @favorite_set.api_posts, root: 'posts'
        end
      end
    end
  end

  def create
    @post = Post.find(params[:post_id])
    FavoriteManager.add!(user: CurrentUser.user, post: @post)
    flash.now[:notice] = "You have favorited this post"

    respond_with(@post)
  rescue Favorite::Error, ActiveRecord::RecordInvalid => x
    render_expected_error(422, x.message)
  end

  def destroy
    @post = Post.find(params[:id])
    FavoriteManager.remove!(user: CurrentUser.user, post: @post)

    flash.now[:notice] = "You have unfavorited this post"
    respond_with(@post)
  rescue Favorite::Error => x
    render_expected_error(422, x.message)
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.favorites_disabled? && !CurrentUser.is_staff?
  end
end
