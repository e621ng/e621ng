# frozen_string_literal: true

require "test_helper"

class ForumPostsControllerTest < ActionDispatch::IntegrationTest
  context "The forum posts controller" do
    setup do
      @user = create(:user)
      @other_user = create(:user)
      @mod = create(:moderator_user)
      as(@user) do
        @forum_topic = create(:forum_topic, title: "my forum topic", original_post_attributes: { body: "alias xxx -> yyy" })
        @forum_post = @forum_topic.original_post
      end
    end

    context "with votes" do
      setup do
        as(@user) do
          @tag_alias = create(:tag_alias, forum_post: @forum_post, status: "pending")
          @vote = create(:forum_post_vote, forum_post: @forum_post, score: 1)
          @forum_post.reload
        end
      end

      should "not render the vote links for the requesting user" do
        get_auth forum_topic_path(@forum_topic), @user
        assert_select "a[title='Vote up']", false
      end

      should "render the vote links" do
        get_auth forum_topic_path(@forum_topic), @mod
        assert_select "a[title='Vote up']"
      end

      should "render existing votes" do
        get_auth forum_topic_path(@forum_topic), @mod
        assert_select "li.vote-score-up"
      end

      context "after the alias is rejected" do
        setup do
          as(@mod) do
            @tag_alias.reject!
          end
          get_auth forum_topic_path(@forum_topic), @mod
        end

        should "hide the vote links" do
          assert_select "a[title='Vote up']", false
        end

        should "still render existing votes" do
          assert_select "li.vote-score-up"
        end
      end
    end

    context "index action" do
      should "list all forum posts" do
        get forum_posts_path
        assert_response :success
      end

      context "with posts in a hidden category" do
        setup do
          as(@mod) do
            @category2 = ForumCategory.create!(name: "test", can_view: @mod.level)
            @forum_topic = create(:forum_topic, category: @category2, title: "test", original_post_attributes: { body: "test" })
            @forum_post2 = @forum_topic.original_post
          end
        end

        should "only list visible posts" do
          get forum_posts_path
          assert_response :success
          assert_select "#forum-post-#{@forum_post.id}", true
          assert_select "#forum-post-#{@forum_post2.id}", false

          get forum_posts_path(format: :json)
          assert_response :success
          assert_equal([@forum_post.id], @response.parsed_body.pluck("id"))
        end
      end

      context "with search conditions" do
        should "list all matching forum posts" do
          get forum_posts_path, params: {:search => {:body_matches => "xxx"}}
          assert_response :success
          assert_select "#forum-post-#{@forum_post.id}"
        end

        should "list nothing for when the search matches nothing" do
          get forum_posts_path, params: {:search => {:body_matches => "bababa"}}
          assert_response :success
          assert_select "#forum-post-#{@forum_post.id}", false
        end

        should "list by creator id" do
          get forum_posts_path, params: {:search => {:creator_id => @user.id}}
          assert_response :success
          assert_select "#forum-post-#{@forum_post.id}"
        end
      end
    end

    context "edit action" do
      should "render if the editor is the creator of the topic" do
        get_auth edit_forum_post_path(@forum_post), @user
        assert_response :success
      end

      should "render if the editor is an admin" do
        get_auth edit_forum_post_path(@forum_post), create(:admin_user)
        assert_response :success
      end

      should "fail if the editor is not the creator of the topic and is not an admin" do
        get_auth edit_forum_post_path(@forum_post), @other_user
        assert_response(403)
      end
    end

    context "new action" do
      should "render" do
        get_auth new_forum_post_path, @user, params: { forum_post: { topic_id: @forum_topic.id }}
        assert_response :success
      end
    end

    context "create action" do
      should "create a new forum post" do
        assert_difference("ForumPost.count", 1) do
          post_auth forum_posts_path, @user, params: {:forum_post => {:body => "xaxaxa", :topic_id => @forum_topic.id}}
        end
      end
    end

    context "destroy action" do
      should "destroy the posts" do
        @admin = create(:admin_user)
        delete_auth forum_post_path(@forum_post), @admin
        get_auth forum_post_path(@forum_post), @admin
        assert_response :not_found
      end
    end

    context "unhide action" do
      setup do
        as(@mod) do
          @forum_post.hide!
        end
      end

      should "restore the post" do
        post_auth unhide_forum_post_path(@forum_post), @mod
        assert_redirected_to(forum_post_path(@forum_post))
        @forum_post.reload
        assert_equal(false, @forum_post.is_hidden?)
      end
    end
  end
end
