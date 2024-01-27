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
          @set = PostSets::Post.new("", 2, 1)
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
            @set = PostSets::Post.new("a")
          end

          should "return the first element" do
            assert_equal(@post_5.id, @set.posts.first.id)
          end
        end

        context "for before the first element" do
          setup do
            @set = PostSets::Post.new("a", "b#{@post_5.id}", 1)
          end

          should "return the second element" do
            assert_equal(@post_4.id, @set.posts.first.id)
          end
        end

        context "for after the second element" do
          setup do
            @set = PostSets::Post.new("a", "a#{@post_4.id}", 1)
          end

          should "return the first element" do
            assert_equal(@post_5.id, @set.posts.first.id)
          end
        end
      end

      context "a set going to the 1,001st page" do
        setup do
          @set = PostSets::Post.new("a", 1_001)
        end

        should "fail" do
          assert_raises(Danbooru::Paginator::PaginationError) do
            @set.posts
          end
        end
      end

      context "#per_page method" do
        should "take the limit from the params first, then the limit:<n> metatag, then the account settings" do
          set = PostSets::Post.new("a limit:23 b", 1, 42)
          assert_equal(42, set.per_page)

          set = PostSets::Post.new("a limit:23 b", 1, nil)
          assert_equal(23, set.per_page)

          set = PostSets::Post.new("a", 1, nil)
          assert_equal(CurrentUser.user.per_page, set.per_page)
        end
      end
    end
  end
end
