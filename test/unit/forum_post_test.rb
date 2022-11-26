require 'test_helper'

class ForumPostTest < ActiveSupport::TestCase
  context "A forum post" do
    setup do
      @user = create(:user)
      CurrentUser.user = @user
      @topic = create(:forum_topic)
    end

    context "#votable?" do
      setup do
        @post = build(:forum_post, topic_id: @topic.id, body: "[[aaa]] -> [[bbb]]")
        @tag_alias = create(:tag_alias, forum_post: @post)
      end

      should "be true for a post associated with a tag alias" do
        assert(@post.votable?)
      end
    end

    context "that belongs to a topic with several pages of posts" do
      setup do
        Danbooru.config.stubs(:posts_per_page).returns(3)
        @posts = []
        9.times do
          @posts << create(:forum_post, topic_id: @topic.id, body: rand(100_000))
        end
        travel_to(2.seconds.from_now) do
          @posts << create(:forum_post, topic_id: @topic.id, body: rand(100_000))
        end
      end

      context "that is deleted" do
        setup do
          CurrentUser.user = create(:moderator_user)
        end

        should "update the topic's updated_at timestamp" do
          @topic.reload
          assert_equal(@posts[-1].updated_at.to_i, @topic.updated_at.to_i)
          @posts[-1].hide!
          @topic.reload
          assert_equal(@posts[-2].updated_at.to_i, @topic.updated_at.to_i)
        end
      end

      should "know which page it's on" do
        assert_equal(2, @posts[3].forum_topic_page)
        assert_equal(2, @posts[4].forum_topic_page)
        assert_equal(3, @posts[5].forum_topic_page)
        assert_equal(3, @posts[6].forum_topic_page)
      end

      should "update the topic's updated_at when destroyed" do
        @posts.last.destroy
        @topic.reload
        assert_equal(@posts[8].updated_at.to_s, @topic.updated_at.to_s)
      end
    end

    context "belonging to a locked topic" do
      setup do
        @post = create(:forum_post, topic_id: @topic.id, body: "zzz")
        @topic.update_attribute(:is_locked, true)
        @post.reload
      end

      should "not be updateable" do
        @post.update(:body => "xxx")
        @post.reload
        assert_equal("zzz", @post.body)
      end

      should "not be deletable" do
        assert_difference("ForumPost.count", 0) do
          @post.destroy
        end
      end
    end

    should "update the topic when created" do
      @original_topic_updated_at = @topic.updated_at
      travel_to(1.second.from_now) do
        post = create(:forum_post, topic_id: @topic.id)
      end
      @topic.reload
      assert_not_equal(@original_topic_updated_at.to_s, @topic.updated_at.to_s)
    end

    should "be searchable by body content" do
      post = create(:forum_post, topic_id: @topic.id, body: "xxx")
      assert_equal(1, ForumPost.search(body_matches: "xxx").count)
      assert_equal(0, ForumPost.search(body_matches: "aaa").count)
    end

    should "initialize its creator" do
      post = create(:forum_post, topic_id: @topic.id)
      assert_equal(@user.id, post.creator_id)
    end

    context "updated by a second user" do
      setup do
        @post = create(:forum_post, topic_id: @topic.id)
        @second_user = create(:user)
        CurrentUser.user = @second_user
      end

      should "record its updater" do
        @post.update(:body => "abc")
        assert_equal(@second_user.id, @post.updater_id)
      end
    end
  end
end
