# frozen_string_literal: true

require "test_helper"

module PostSets
  class FavoritesTest < ActiveSupport::TestCase
    context "In all cases" do
      setup do
        @user = create(:user)
        CurrentUser.user = @user

        @post_1 = create(:post)
        @post_2 = create(:post)
        @post_3 = create(:post)
        FavoriteManager.add!(user: @user, post: @post_2)
        FavoriteManager.add!(user: @user, post: @post_1)
        FavoriteManager.add!(user: @user, post: @post_3)
      end

      context "a favorite set for before the most recent post" do
        setup do
          id = ::Favorite.where(user_id: @user.id, post_id: @post_3.id).first.id
          @set = PostSets::Favorites.new(@user, "b#{id}", limit: 1)
        end

        context "a sequential paginator" do
          should "return the second most recent element" do
            assert_equal(@post_1.id, @set.posts.first.id)
          end

          # FIXME: PaginatedArray does not preserve mode and mode_seq
          should_eventually "know what page it's on" do
            refute(@set.posts.is_first_page?)
            refute(@set.posts.is_last_page?)
          end
        end
      end

      context "a favorite set for after the third most recent post" do
        setup do
          id = ::Favorite.where(user_id: @user.id, post_id: @post_2.id).first.id
          @set = PostSets::Favorites.new(@user, "a#{id}", limit: 1)
        end

        context "a sequential paginator" do
          should "return the second most recent element" do
            assert_equal(@post_1.id, @set.posts.first.id)
          end
        end
      end

      context "a favorite set for before the second most recent post" do
        setup do
          id = ::Favorite.where(user_id: @user.id, post_id: @post_1.id).first.id
          @set = PostSets::Favorites.new(@user, "b#{id}", limit: 1)
        end

        context "a sequential paginator" do
          should "return the third most recent element" do
            assert_equal(@post_2.id, @set.posts.first.id)
          end
        end
      end

      context "a favorite set for after the second most recent post" do
        setup do
          id = ::Favorite.where(user_id: @user.id, post_id: @post_1.id).first.id
          @set = PostSets::Favorites.new(@user, "a#{id}", limit: 1)
        end

        context "a sequential paginator" do
          should "return the most recent element" do
            assert_equal(@post_3.id, @set.posts.first.id)
          end
        end
      end

      context "a favorite set for page 2" do
        setup do
          @set = PostSets::Favorites.new(@user, 2, limit: 1)
        end

        context "a numbered paginator" do
          should "return the second most recent element" do
            assert_equal(@post_1.id, @set.posts.first.id)
          end
        end
      end

      context "a favorite set with no page specified" do
        setup do
          @set = PostSets::Favorites.new(@user, nil, limit: 1)
        end

        should "return the most recent element" do
          assert_equal(@post_3.id, @set.posts.first.id)
        end
      end
    end
  end
end
