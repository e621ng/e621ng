require 'test_helper'

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  context "The favorites controller" do
    setup do
      @user = create(:user)
      as_user do
        @post = create(:post)
      end
    end

    context "index action" do
      setup do
        FavoriteManager.add!(user: @user, post: @post)
      end

      context "with a specified tags parameter" do
        should "redirect to the posts controller" do
          get_auth favorites_path, @user, params: { tags: "fav:#{@user.name} abc" }
          assert_redirected_to(posts_path(tags: "fav:#{@user.name} abc"))
        end
      end

      should "display the current user's favorites" do
        get_auth favorites_path, @user
        assert_response :success
      end
    end

    context "create action" do
      should "create a favorite for the current user" do
        assert_difference(-> { Favorite.count }, 1) do
          post_auth favorites_path, @user, params: { format: :json, post_id: @post.id }
        end
      end
    end

    context "destroy action" do
      setup do
        FavoriteManager.add!(user: @user, post: @post)
      end

      should "remove the favorite from the current user" do
        assert_difference(-> { Favorite.count }, -1) do
          delete_auth favorite_path(@post.id), @user, params: { format: :json }
        end
      end
    end
  end
end
