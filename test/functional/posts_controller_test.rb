# frozen_string_literal: true

require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  context "The posts controller" do
    setup do
      @user = create(:user, created_at: 1.month.ago)
      as(@user) do
        @post = create(:post, tag_string: "aaaa")
      end
    end

    context "index action" do
      should "render" do
        get posts_path
        assert_response :success
      end

      context "with a search" do
        should "render" do
          get posts_path, params: {:tags => "aaaa"}
          assert_response :success
        end
      end

      context "with an md5 param" do
        should "render" do
          get posts_path, params: { md5: @post.md5 }
          assert_redirected_to(@post)
        end

        should "return error on nonexistent md5" do
          get posts_path(md5: "foo")
          assert_response 404
        end
      end

      context "with a random search" do
        should "render" do
          get posts_path, params: { tags: "order:random" }
          assert_response :success

          get posts_path, params: { random: "1" }
          assert_response :success
        end
      end

      context "with an invalid date search" do
        should "return empty results for dates with years outside OpenSearch range" do
          get posts_path, params: { tags: "date:23025-05-24" }
          assert_response :success
        end
      end
    end

    context "show_seq action" do
      should "render" do
        posts = create_list(:post, 3)

        get show_seq_post_path(posts[1].id), params: { seq: "prev" }
        assert_response :success

        get show_seq_post_path(posts[1].id), params: { seq: "next" }
        assert_response :success
      end
    end

    context "show action" do
      should "render" do
        get post_path(@post), params: {:id => @post.id}
        assert_response :success
      end
    end

    context "update action" do
      should "work" do
        put_auth post_path(@post), @user, params: {:post => {:tag_string => "bbb"}}
        assert_redirected_to post_path(@post)

        @post.reload
        assert_equal("bbb", @post.tag_string)
      end

      should "ignore restricted params" do
        put_auth post_path(@post), @user, params: {:post => {:last_noted_at => 1.minute.ago}}
        assert_nil(@post.reload.last_noted_at)
      end

      should "allow moderators to lock comments" do
        assert_difference("PostEvent.count", 1) do
          put_auth post_path(@post), create(:moderator_user), params: { post: { is_comment_locked: true } }
        end
        assert_equal(true, @post.reload.is_comment_locked?)
        assert_equal("comment_locked", PostEvent.last.action)
      end

      should "allow moderators to unlock comments" do
        @post.update_columns(is_comment_locked: true)
        assert_difference("PostEvent.count", 1) do
          put_auth post_path(@post), create(:moderator_user), params: { post: { is_comment_locked: false } }
        end
        assert_equal(false, @post.reload.is_comment_locked?)
        assert_equal("comment_unlocked", PostEvent.last.action)
      end

      should "not allow moderators to disable comments" do
        assert_no_difference("PostEvent.count") do
          put_auth post_path(@post), create(:moderator_user), params: { post: { is_comment_disabled: true } }
        end
        assert_equal(false, @post.reload.is_comment_disabled?)
      end

      should "not allow moderators to enable comments" do
        @post.update_columns(is_comment_disabled: true)
        assert_no_difference("PostEvent.count") do
          put_auth post_path(@post), create(:moderator_user), params: { post: { is_comment_disabled: false } }
        end
        assert_equal(true, @post.reload.is_comment_disabled?)
      end
    end

    context "revert action" do
      setup do
        as(@user) do
          @post.update(tag_string: "zzz")
        end
      end

      should "work" do
        @version = @post.versions.first
        assert_equal("aaaa", @version.tags)
        put_auth revert_post_path(@post), @user, params: {:version_id => @version.id}
        assert_redirected_to post_path(@post)
        @post.reload
        assert_equal("aaaa", @post.tag_string)
      end

      should "not allow reverting to a previous version of another post" do
        as(@user) do
          @post2 = create(:post, uploader_id: @user.id, tag_string: "herp")
        end

        put_auth revert_post_path(@post), @user, params: { :version_id => @post2.versions.first.id }
        @post.reload
        assert_not_equal(@post.tag_string, @post2.tag_string)
        assert_response :missing
      end
    end
  end
end
