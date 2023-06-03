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

    context "when modified" do
      setup do
        @forum_post = create(:forum_post, topic_id: @topic.id)
        original_body = @forum_post.body
        @forum_post.class_eval do
          after_save do
            if @body_history.nil?
              @body_history = [original_body]
            end
            @body_history.push(body)
          end

          define_method :body_history do
            @body_history
          end
        end
      end

      instance_exec do
        define_method :verify_history do |history, forum_post, edit_type, user = forum_post.creator_id|
          throw "history is nil (#{forum_post.id}:#{edit_type}:#{user}:#{forum_post.creator_id})" if history.nil?
          assert_equal(forum_post.body_history[history.version - 1], history.body, "history body did not match")
          assert_equal(edit_type, history.edit_type, "history edit_type did not match")
          assert_equal(user, history.user_id, "history user_id did not match")
        end
      end

      should "create edit histories when body is changed" do
        @mod = create(:moderator_user)
        assert_difference("EditHistory.count", 3) do
          @forum_post.update(body: "test")
          as(@mod) { @forum_post.update(body: "test2") }

          original, edit, edit2 = EditHistory.where(versionable_id: @forum_post.id).order(version: :asc)
          verify_history(original, @forum_post, "original", @user.id)
          verify_history(edit, @forum_post, "edit", @user.id)
          verify_history(edit2, @forum_post, "edit", @mod.id)
        end
      end

      should "create edit histories when hidden is changed" do
        @mod = create(:moderator_user)
        assert_difference("EditHistory.count", 3) do
          @forum_post.hide!
          as(@mod) { @forum_post.unhide! }

          original, hide, unhide = EditHistory.where(versionable_id: @forum_post.id).order(version: :asc)
          verify_history(original, @forum_post, "original")
          verify_history(hide, @forum_post, "hide")
          verify_history(unhide, @forum_post, "unhide", @mod.id)
        end
      end

      should "create edit histories when warning is changed" do
        @mod = create(:moderator_user)
        assert_difference("EditHistory.count", 7) do
          as(@mod) do
            @forum_post.user_warned!("warning", @mod)
            @forum_post.remove_user_warning!
            @forum_post.user_warned!("record", @mod)
            @forum_post.remove_user_warning!
            @forum_post.user_warned!("ban", @mod)
            @forum_post.remove_user_warning!

            original, warn, unmark1, record, unmark2, ban, unmark3 = EditHistory.where(versionable_id: @forum_post.id).order(version: :asc)
            verify_history(original, @forum_post, "original")
            verify_history(warn, @forum_post, "mark_warning", @mod.id)
            verify_history(unmark1, @forum_post, "unmark", @mod.id)
            verify_history(record, @forum_post, "mark_record", @mod.id)
            verify_history(unmark2, @forum_post, "unmark", @mod.id)
            verify_history(ban, @forum_post, "mark_ban", @mod.id)
            verify_history(unmark3, @forum_post, "unmark", @mod.id)
          end
        end
      end
    end
  end
end
