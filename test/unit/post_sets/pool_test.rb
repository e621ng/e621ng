# frozen_string_literal: true

require "test_helper"

module PostSets
  class PoolTest < ActiveSupport::TestCase
    context "In all cases" do
      setup do
        @user = create(:user)
        CurrentUser.user = @user

        @post1 = create(:post)
        @post2 = create(:post)
        @post3 = create(:post)
        @pool = create(:pool)
        @pool.add!(@post2)
        @pool.add!(@post1)
        @pool.add!(@post3)
      end

      context "a post pool set for page 2" do
        setup do
          @post_page = @pool.posts.paginate(2, limit: 1)
        end

        should "return the second element" do
          assert_equal(1, @post_page.size)
          assert_equal(@post1, @post_page.first)
        end

        should "know the total number of pages" do
          assert_equal(3, @post_page.total_pages)
        end

        should "know the current page" do
          assert_equal(2, @post_page.current_page)
        end
      end

      context "a post pool set with no page specified" do
        setup do
          @post_page = @pool.posts.paginate(nil, limit: 1)
        end

        should "return the first element" do
          assert_equal(1, @post_page.size)
          assert_equal(@post2, @post_page.first)
        end
      end
    end
  end
end
