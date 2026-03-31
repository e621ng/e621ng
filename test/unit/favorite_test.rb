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
    should "be created" do
      FavoriteManager.add!(user: @user1, post: @p1)
      assert @p1.favorited_by?(@user1.id)
      assert_equal(1, Favorite.count)
    end

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

    should "handle remove when only fav_string entry exists" do
      # Orphaned fav_string entry
      @p1.append_user_to_fav_string(@user1.id)
      @p1.save
      assert @p1.favorited_by?(@user1.id)
      assert_equal(0, Favorite.count)

      # Cleanup
      FavoriteManager.remove!(user: @user1, post: @p1)
      @p1.reload

      assert_not @p1.favorited_by?(@user1.id)
      assert_equal(0, Favorite.count)
    end

    should "handle remove when only database record exists" do
      # Orphaned database record
      Favorite.create(user: @user1, post: @p1)
      assert_not @p1.favorited_by?(@user1.id)
      assert_equal(1, Favorite.count)

      # Cleanup
      FavoriteManager.remove!(user: @user1, post: @p1)

      assert_not @p1.favorited_by?(@user1.id)
      assert_equal(0, Favorite.count)
    end

    should "handle add when an orphaned database record exists" do
      # Orphaned database record
      Favorite.create(user: @user1, post: @p1)
      @p1.reload
      assert_not @p1.favorited_by?(@user1.id)
      assert_equal(1, Favorite.count)

      # Cleanup
      assert_nothing_raised do
        FavoriteManager.add!(user: @user1, post: @p1)
      end

      @p1.reload
      assert @p1.favorited_by?(@user1.id)
      assert_equal(1, Favorite.count)
    end

    should "handle hybrid approach for posts with many favorites" do
      # Set a range that is guaranteed to not include any test user IDs
      max_user_id = [@user1.id, @user2.id].max
      start_id = max_user_id + 1000
      existing_favs = (start_id..(start_id + 1000)).map { |i| "fav:#{i}" }.join(" ")
      @p1.update_columns(fav_string: existing_favs, fav_count: 1001)
      @p1.reload

      # Adding a favorite
      FavoriteManager.add!(user: @user1, post: @p1)
      @p1 = Post.find(@p1.id) # Force a database round-trip

      assert @p1.favorited_by?(@user1.id)
      assert_equal(1, Favorite.count)
      assert_equal(1002, @p1.fav_count)
      assert_match(/(?:\A| )fav:#{@user1.id}(?:\Z| )/, @p1.fav_string)

      # Removing the favorite
      FavoriteManager.remove!(user: @user1, post: @p1)
      @p1.reload

      assert_not @p1.favorited_by?(@user1.id)
      assert_equal(0, Favorite.count)
      assert_equal(1001, @p1.fav_count)
      assert_no_match(/(?:\A| )fav:#{@user1.id}(?:\Z| )/, @p1.fav_string)

      # Verify original favorites
      assert_match(/(?:\A| )fav:#{start_id}(?:\Z| )/, @p1.fav_string)
      assert_match(/(?:\A| )fav:#{start_id + 1000}(?:\Z| )/, @p1.fav_string)
    end

    should "handle hybrid approach for posts with few favorites" do
      # Set a range that is guaranteed to not include any test user IDs
      max_user_id = [@user1.id, @user2.id].max
      start_id = max_user_id + 1000
      existing_favs = (start_id..(start_id + 499)).map { |i| "fav:#{i}" }.join(" ")
      @p1.update_columns(fav_string: existing_favs, fav_count: 500)
      @p1.reload

      # Adding a favorite
      FavoriteManager.add!(user: @user1, post: @p1)
      @p1.reload
      @p1 = Post.find(@p1.id) # Force a database round-trip

      assert @p1.favorited_by?(@user1.id)
      assert_equal(1, Favorite.count)
      assert_equal(501, @p1.fav_count)
      assert_match(/(?:\A| )fav:#{@user1.id}(?:\Z| )/, @p1.fav_string)

      # Removing the favorite
      FavoriteManager.remove!(user: @user1, post: @p1)
      @p1.reload

      assert_not @p1.favorited_by?(@user1.id)
      assert_equal(0, Favorite.count)
      assert_equal(500, @p1.fav_count)
      assert_no_match(/(?:\A| )fav:#{@user1.id}(?:\Z| )/, @p1.fav_string)

      # Verify original favorites are still there
      assert_match(/(?:\A| )fav:#{start_id}(?:\Z| )/, @p1.fav_string)
      assert_match(/(?:\A| )fav:#{start_id + 499}(?:\Z| )/, @p1.fav_string)
    end
  end
end
