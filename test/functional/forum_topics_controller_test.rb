# frozen_string_literal: true

require "test_helper"

class ForumTopicsControllerTest < ActionDispatch::IntegrationTest
  context "The forum topics controller" do
    setup do
      @user = create(:user)
      @other_user = create(:user)
      @mod = create(:moderator_user)

      as(@user) do
        @forum_topic = create(:forum_topic, title: "my forum topic", original_post_attributes: { body: "xxx" })
      end
    end

    context "show action" do
      should "render" do
        get forum_topic_path(@forum_topic)
        assert_response :success
      end

      should "record a topic visit for html requests" do
        get_auth forum_topic_path(@forum_topic), @user
        @user.reload
        assert_not_nil(@user.last_forum_read_at)
      end

      should "not record a topic visit for non-html requests" do
        get_auth forum_topic_path(@forum_topic), @user, params: {format: :json}
        @user.reload
        assert_nil(@user.last_forum_read_at)
      end

      should "have the correct page number" do
        Danbooru.config.stubs(:records_per_page).returns(2)
        assert_equal(1, @forum_topic.last_page)
        as(@user) { @forum_posts = create_list(:forum_post, 3, topic: @forum_topic) }
        assert_equal(2, @forum_topic.last_page)

        get_auth forum_topic_path(@forum_topic), @user, params: { page: 2 }
        assert_select "#forum_post_#{@forum_posts.second.id}"
        assert_select "#forum_post_#{@forum_posts.third.id}"
        assert_equal([1, 2, 2], @forum_posts.map(&:forum_topic_page))
        assert_equal(2, @forum_topic.last_page)

        as(@mod) { @forum_posts.first.hide! }
        get_auth forum_topic_path(@forum_topic), @user, params: { page: 2 }
        assert_select "#forum_post_#{@forum_posts.second.id}"
        assert_select "#forum_post_#{@forum_posts.third.id}"
        assert_equal([1, 2, 2], @forum_posts.map(&:forum_topic_page))
        assert_equal(2, @forum_topic.last_page)
      end
    end

    context "index action" do
      setup do
        as(@user) do
          @topic1 = create(:forum_topic, title: "a", is_sticky: true, original_post_attributes: { body: "xxx" })
          @topic2 = create(:forum_topic, title: "b", original_post_attributes: { body: "xxx" })
        end
      end

      should "list all forum topics" do
        get forum_topics_path
        assert_response :success
      end

      should "not list stickied topics first for JSON responses" do
        get forum_topics_path, params: {format: :json}
        forum_topics = JSON.parse(response.body)
        assert_equal([@topic2.id, @topic1.id, @forum_topic.id], forum_topics.map {|t| t["id"]})
      end

      context "with search conditions" do
        should "list all matching forum topics" do
          get forum_topics_path, params: {:search => {:title_matches => "forum"}}
          assert_response :success
          assert_select "a.forum-post-link", @forum_topic.title
          assert_select "a.forum-post-link", {count: 0, text: @topic1.title}
          assert_select "a.forum-post-link", {count: 0, text: @topic2.title}
        end

        should "list nothing for when the search matches nothing" do
          get forum_topics_path, params: {:search => {:title_matches => "bababa"}}
          assert_response :success
          assert_select "a.forum-post-link", {count: 0, text: @forum_topic.title}
          assert_select "a.forum-post-link", {count: 0, text: @topic1.title}
          assert_select "a.forum-post-link", {count: 0, text: @topic2.title}
        end
      end
    end

    context "edit action" do
      should "render if the editor is the creator of the topic" do
        get_auth edit_forum_topic_path(@forum_topic), @user
        assert_response :success
      end

      should "render if the editor is a moderator" do
        get_auth edit_forum_topic_path(@forum_topic), @mod
        assert_response :success
      end

      should "fail if the editor is not the creator of the topic and is not a moderator" do
        get_auth edit_forum_topic_path(@forum_topic), @other_user
        assert_response(403)
      end
    end

    context "new action" do
      should "render" do
        get_auth new_forum_topic_path, @user
        assert_response :success
      end
    end

    context "create action" do
      should "create a new forum topic and post" do
        assert_difference(["ForumPost.count", "ForumTopic.count"], 1) do
          post_auth forum_topics_path, @user, params: {:forum_topic => {:title => "bababa", :category_id => Danbooru.config.alias_implication_forum_category, :original_post_attributes => {:body => "xaxaxa"}}}
        end

        forum_topic = ForumTopic.last
        assert_redirected_to(forum_topic_path(forum_topic))
      end

      should "fail with expected error if invalid category_id is provided" do
        post_auth forum_topics_path, @user, params: { forum_topic: { title: "bababa", category_id: 0, original_post_attributes: { body: "xaxaxa" } }, format: :json }

        assert_response :unprocessable_content
        assert_includes(@response.parsed_body.dig("errors", "category"), "is invalid")
      end
    end

    context "destroy action" do
      setup do
        as(@user) do
          @post = create(:forum_post, topic_id: @forum_topic.id)
        end
      end

      should "destroy the topic and any associated posts" do
        delete_auth forum_topic_path(@forum_topic), create(:admin_user)
        assert_redirected_to(forum_topics_path)
        assert_raises(ActiveRecord::RecordNotFound) { @forum_topic.reload }
      end
    end

    context "unhide action" do
      setup do
        as(@mod) do
          @forum_topic.hide!
        end
      end

      should "restore the topic" do
        post_auth unhide_forum_topic_path(@forum_topic), @mod
        assert_redirected_to(forum_topic_path(@forum_topic))
        @forum_topic.reload
        assert(!@forum_topic.is_hidden?)
      end
    end
  end
end
