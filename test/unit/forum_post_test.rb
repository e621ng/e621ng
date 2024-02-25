# frozen_string_literal: true

require "test_helper"

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
          @posts << create(:forum_post, topic_id: @topic.id)
        end
        travel_to(2.seconds.from_now) do
          @posts << create(:forum_post, topic_id: @topic.id)
        end
      end

      context "that is deleted" do
        setup do
          CurrentUser.user = create(:moderator_user)
        end

        should "update the topic's updated_at timestamp" do
          @topic.reload
          assert_in_delta(@posts[-1].updated_at.to_i, @topic.updated_at.to_i, 1)
          @posts[-1].hide!
          @topic.reload
          assert_in_delta(@posts[-2].updated_at.to_i, @topic.updated_at.to_i, 1)
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

    context "that is edited by a moderator" do
      setup do
        @post = create(:forum_post, topic_id: @topic.id)
        @mod = create(:moderator_user)
        CurrentUser.user = @mod
      end

      should "create a mod action" do
        assert_difference(-> { ModAction.count }, 1) do
          @post.update(body: "nope")
        end
      end

      should "credit the moderator as the updater" do
        @post.update(body: "test")
        assert_equal(@mod.id, @post.updater_id)
      end
    end

    context "that is hidden by a moderator" do
      setup do
        @post = create(:forum_post, topic_id: @topic.id)
        @mod = create(:moderator_user)
        CurrentUser.user = @mod
      end

      should "create a mod action" do
        assert_difference(-> { ModAction.count }, 1) do
          @post.update(is_hidden: true)
        end
      end

      should "credit the moderator as the updater" do
        @post.update(is_hidden: true)
        assert_equal(@mod.id, @post.updater_id)
      end
    end

    context "that is deleted" do
      setup do
        @post = create(:forum_post, topic_id: @topic.id)
      end

      should "create a mod action" do
        assert_difference(-> { ModAction.count }, 1) do
          @post.destroy
        end
      end
    end

    context "during validation" do
      subject { build(:forum_post) }
      should_not allow_value(" ").for(:body)
    end
  end
end
