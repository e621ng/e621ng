# frozen_string_literal: true

require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  context "A comments controller" do
    setup do
      @mod = create(:moderator_user)
      @user = create(:member_user)
      CurrentUser.user = @user

      @post = create(:post)
      @comment = create(:comment, post: @post)
      as(@mod) do
        @mod_comment = create(:comment, post: @post)
      end
    end

    context "index action" do
      should "render for post" do
        get comments_path(post_id: @post.id, group_by: "post")
        assert_response :success
      end

      should "render by post" do
        get comments_path(group_by: "post")
        assert_response :success
      end

      should "render by comment" do
        get comments_path(group_by: "comment")
        assert_response :success
      end

      should "render for the poster_id search parameter" do
        get comments_path(group_by: "comment", search: { poster_id: 123 })
        assert_response :success
      end
    end

    context "search action" do
      should "render" do
        get search_comments_path
        assert_response :success
      end
    end

    context "show action" do
      should "render" do
        get comment_path(@comment.id)
        assert_response :success
      end
    end

    context "edit action" do
      should "render" do
        get_auth edit_comment_path(@comment.id), @user

        assert_response :success
      end
    end

    context "update action" do
      context "when updating another user's comment" do
        should "succeed if updater is a moderator" do
          put_auth comment_path(@comment.id), @user, params: { comment: { body: "abc" } }
          assert_equal("abc", @comment.reload.body)
          assert_redirected_to post_path(@comment.post)
        end

        should "fail if updater is not a moderator" do
          put_auth comment_path(@mod_comment.id), @user, params: { comment: { body: "abc" } }
          assert_not_equal("abc", @mod_comment.reload.body)
          assert_response 403
        end
      end

      context "when stickying a comment" do
        should "succeed if updater is a moderator" do
          @comment = create(:comment, creator: @mod)
          put_auth comment_path(@comment.id), @mod, params: { comment: { is_sticky: true } }
          assert_equal(true, @comment.reload.is_sticky)
          assert_redirected_to @comment.post
        end

        should "fail if updater is not a moderator" do
          put_auth comment_path(@comment.id), @user, params: { comment: { is_sticky: true } }
          assert_equal(false, @comment.reload.is_sticky)
        end
      end

      should "update the body" do
        put_auth comment_path(@comment.id), @user, params: { comment: { body: "abc" } }
        assert_equal("abc", @comment.reload.body)
        assert_redirected_to post_path(@comment.post)
      end

      should "not allow changing is_hidden" do
        put_auth comment_path(@comment.id), @user, params: { comment: { body: "herp derp", is_hidden: true } }
        assert_equal(false, @comment.is_hidden)
      end

      should "not allow changing do_not_bump_post or post_id" do
        as(@user) do
          @another_post = create(:post)
        end
        put_auth comment_path(@comment.id), @comment.creator, params: { comment: { do_not_bump_post: true, post_id: @another_post.id } }
        assert_equal(false, @comment.reload.do_not_bump_post)
        assert_equal(@post.id, @comment.post_id)
      end

      should "not allow changing comments on comment locked posts" do
        @post.update(is_comment_locked: true)
        body = @comment.body
        put_auth comment_path(@comment.id), @user, params: { comment: { body: "abc" } }
        assert_response(:forbidden)
        assert_equal(body, @comment.reload.body)
      end

      should "not allow changing comments on comment disabled posts" do
        @post.update(is_comment_disabled: true)
        body = @comment.body
        put_auth comment_path(@comment.id), @user, params: { comment: { body: "abc" } }
        assert_response(:forbidden)
        assert_equal(body, @comment.reload.body)
      end
    end

    context "new action" do
      should "redirect" do
        get_auth new_comment_path, @user
        assert_response :success
      end
    end

    context "create action" do
      should "create a comment" do
        assert_difference("Comment.count", 1) do
          post_auth comments_path, @user, params: { comment: { body: "abc", post_id: @post.id } }
        end
        comment = Comment.last
        assert_redirected_to post_path(comment.post)
      end

      should "not allow commenting on nonexistent posts" do
        assert_difference("Comment.count", 0) do
          post_auth comments_path, @user, params: { comment: { body: "abc", post_id: -1 } }
        end
        assert_redirected_to comments_path
      end

      should "not allow commenting on comment locked posts" do
        @post.update(is_comment_locked: true)
        assert_difference("Comment.count", 0) do
          post_auth comments_path, @user, params: { comment: { body: "abc", post_id: @post.id } }
          assert_redirected_to(post_path(@post))
          assert_equal("Post has comments locked", flash[:notice])
        end
      end

      should "not allow commenting on comment disabled posts" do
        @post.update(is_comment_disabled: true)
        assert_difference("Comment.count", 0) do
          post_auth comments_path, @user, params: { comment: { body: "abc", post_id: @post.id } }
          assert_redirected_to(post_path(@post))
          assert_equal("Post has comments disabled", flash[:notice])
        end
      end
    end

    context "hide action" do
      should "mark comment as hidden" do
        post_auth hide_comment_path(@comment), @user
        assert_equal(true, @comment.reload.is_hidden)
        assert_redirected_to @comment
      end

      should "not allow hiding comments on comment disabled posts" do
        @post.update(is_comment_disabled: true)
        post_auth hide_comment_path(@comment), @user
        assert_equal(false, @comment.reload.is_hidden)
        assert_response(403)
      end
    end

    context "unhide action" do
      setup do
        @comment.hide!
      end

      should "mark comment as unhidden if mod" do
        post_auth unhide_comment_path(@comment), @mod
        assert_equal(false, @comment.reload.is_hidden)
        assert_redirected_to(@comment)
      end

      should "not mark comment as unhidden if not mod" do
        post_auth unhide_comment_path(@comment), @user
        assert_equal(true, @comment.reload.is_hidden)
        assert_response :forbidden
      end
    end

    context "destroy action" do
      should "destroy the comment" do
        delete_auth comment_path(@comment), create(:admin_user)
        assert_equal(0, Comment.where(id: @comment.id).count)
      end
    end
  end
end
