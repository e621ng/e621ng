# frozen_string_literal: true

require "test_helper"

module PostSets
  class PostTest < ActiveSupport::TestCase
    context "In all cases" do
      setup do
        @user = create(:user)
        CurrentUser.user = @user

        @post_1 = create(:post, tag_string: "a")
        @post_2 = create(:post, tag_string: "b")
        @post_3 = create(:post, tag_string: "c")
      end

      context "a set for page 2" do
        setup do
          @set = PostSets::Post.new("", 2, limit: 1)
        end

        should "return the second element" do
          assert_equal(@post_2.id, @set.posts.first.id)
        end
      end

      context "a set for the 'a' tag query" do
        setup do
          @post_4 = create(:post, tag_string: "a")
          @post_5 = create(:post, tag_string: "a")
        end

        context "with no page" do
          setup do
            @set = PostSets::Post.new("a", nil)
          end

          should "return the first element" do
            assert_equal(@post_5.id, @set.posts.first.id)
          end
        end

        context "for before the first element" do
          setup do
            @set = PostSets::Post.new("a", "b#{@post_5.id}", limit: 1)
          end

          should "return the second element" do
            assert_equal(@post_4.id, @set.posts.first.id)
          end
        end

        context "for after the second element" do
          setup do
            @set = PostSets::Post.new("a", "a#{@post_4.id}", limit: 1)
          end

          should "return the first element" do
            assert_equal(@post_5.id, @set.posts.first.id)
          end
        end
      end

      context "#limit method" do
        should "take the limit from the params first, then the limit:<n> metatag" do
          set = PostSets::Post.new("a limit:23 b", 1, limit: "42")
          assert_equal("42", set.limit)

          set = PostSets::Post.new("a limit:23 b", 1)
          assert_equal("23", set.limit)

          set = PostSets::Post.new("a", 1)
          assert_nil(set.limit)
        end
      end
    end
  end
end
