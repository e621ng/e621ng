# frozen_string_literal: true

require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  setup do
    @user1 = create(:user)
    @user2 = create(:user)
    @p1 = create(:post)
    @p2 = create(:post)

    CurrentUser.user = @user1
  end

  context "A favorite" do
    should "delete from all tables" do
      FavoriteManager.add!(user: @user1, post: @p1)
      @user1.reload
      assert_equal(1, @user1.favorite_count)

      FavoriteManager.remove!(user: @user1, post: @p1)
      assert_equal(0, Favorite.count)
    end

    should "know which table it belongs to" do
      FavoriteManager.add!(user: @user1, post: @p1)
      FavoriteManager.add!(user: @user1, post: @p2)
      FavoriteManager.add!(user: @user2, post: @p1)

      favorites = @user1.favorites.order("id desc")
      assert_equal(2, favorites.count)
      assert_equal(@p2.id, favorites[0].post_id)
      assert_equal(@p1.id, favorites[1].post_id)

      favorites = @user2.favorites.order("id desc")
      assert_equal(1, favorites.count)
      assert_equal(@p1.id, favorites[0].post_id)
    end

    should "not allow duplicates" do
      FavoriteManager.add!(user: @user1, post: @p1)
      error = assert_raises(Favorite::Error) { FavoriteManager.add!(user: @user1, post: @p1) }

      assert_equal("You have already favorited this post", error.message)
      @user1.reload
      assert_equal(1, @user1.favorite_count)
    end

    should "not allow exceeding the user's favorite limit" do
      @user1.stubs(:favorite_limit).returns(0)
      error = assert_raises(Favorite::Error) { FavoriteManager.add!(user: @user1, post: @p1) }

      assert_equal("You can only keep up to 0 favorites.", error.message)
    end
  end
end
