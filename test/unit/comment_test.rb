# frozen_string_literal: true

require "test_helper"

class CommentTest < ActiveSupport::TestCase
  context "A comment" do
    setup do
      @user = create(:user)
      CurrentUser.user = @user
    end

    context "created by a limited user" do
      setup do
        Danbooru.config.stubs(:disable_throttles?).returns(false)
      end

      should "fail creation" do
        comment = build(:comment, post: create(:post))
        comment.save
        assert_equal(["Creator can not yet perform this action. Account is too new"], comment.errors.full_messages)
      end
    end

    context "created by an unlimited user" do
      setup do
        Danbooru.config.stubs(:member_comment_limit).returns(100)
      end

      context "that is then deleted" do
        setup do
          @post = create(:post)
          @comment = create(:comment, post_id: @post.id)
          @comment.destroy
          @post.reload
        end

        should "nullify the last_commented_at field" do
          assert_nil(@post.last_commented_at)
        end
      end

      should "be created" do
        post = create(:post)
        comment = build(:comment, post: post)
        comment.save
        assert(comment.errors.empty?, comment.errors.full_messages.join(", "))
      end

      should "not validate if the post does not exist" do
        comment = build(:comment, post_id: -1)

        assert_not(comment.valid?)
        assert_match(/must exist/, comment.errors[:post].join(", "))
      end

      should "not bump the parent post" do
        post = create(:post)
        comment = create(:comment, do_not_bump_post: true, post: post)
        post.reload
        assert_nil(post.last_comment_bumped_at)

        comment = create(:comment, post: post)
        post.reload
        assert_not_nil(post.last_comment_bumped_at)
      end

      should "not bump the post after exceeding the threshold" do
        Danbooru.config.stubs(:comment_threshold).returns(1)
        p = create(:post)
        c1 = create(:comment, post: p)
        travel_to(2.seconds.from_now) do
          c2 = create(:comment, post: p)
        end
        p.reload
        assert_equal(c1.created_at.to_s, p.last_comment_bumped_at.to_s)
      end

      should "always record the last_commented_at properly" do
        post = create(:post)
        Danbooru.config.stubs(:comment_threshold).returns(1)

        c1 = create(:comment, do_not_bump_post: true, post: post)
        post.reload
        assert_equal(c1.created_at.to_s, post.last_commented_at.to_s)

        c2 = create(:comment, post: post)
        post.reload
        assert_equal(c2.created_at.to_s, post.last_commented_at.to_s)
      end

      should "not record the user id of the voter" do
        user = create(:user)
        user2 = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post)

        as(user2) do
          VoteManager.comment_vote!(user: user2, comment: c1, score: -1)
          c1.reload
          assert_not_equal(user2.id, c1.updater_id)
        end
      end

      should "not allow duplicate votes" do
        user = create(:user)
        user2 = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post)
        c2 = create(:comment, post: post)

        as(user2) do
          assert_nothing_raised { VoteManager.comment_vote!(user: user2, comment: c1, score: -1) }
          assert_equal(:need_unvote, VoteManager.comment_vote!(user: user2, comment: c1, score: -1))
          assert_equal(1, CommentVote.count)
          assert_equal(-1, CommentVote.last.score)

          assert_nothing_raised { VoteManager.comment_vote!(user: user2, comment: c2, score: -1) }
          assert_equal(2, CommentVote.count)
        end
      end

      should "not allow upvotes by the creator" do
        user = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post)

        exception = assert_raises(ActiveRecord::RecordInvalid) { VoteManager.comment_vote!(user: user, comment: c1, score: 1) }
        assert_equal("Validation failed: You cannot vote on your own comments", exception.message)
      end

      should "not allow downvotes by the creator" do
        user = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post)

        exception = assert_raises(ActiveRecord::RecordInvalid) { VoteManager.comment_vote!(user: user, comment: c1, score: -1) }
        assert_equal("Validation failed: You cannot vote on your own comments", exception.message)
      end

      should "not allow votes on sticky comments" do
        user = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post, is_sticky: true)

        exception = assert_raises(ActiveRecord::RecordInvalid) { VoteManager.comment_vote!(user: user, comment: c1, score: -1) }
        assert_match(/You cannot vote on sticky comments/, exception.message)
      end

      should "allow undoing of votes" do
        user = create(:user)
        user2 = create(:user)
        post = create(:post)
        comment = create(:comment, post: post)
        as(user2) do
          VoteManager.comment_vote!(user: user2, comment: comment, score: 1)
          comment.reload
          assert_equal(1, comment.score)
          VoteManager.comment_unvote!(user: user2, comment: comment)
          comment.reload
          assert_equal(0, comment.score)
          assert_nothing_raised { VoteManager.comment_vote!(user: user2, comment: comment, score: -1) }
        end
      end

      should "be searchable" do
        c1 = create(:comment, body: "aaa bbb ccc")
        c2 = create(:comment, body: "aaa ddd")
        c3 = create(:comment, body: "eee")

        matches = Comment.search(body_matches: "aaa")
        assert_equal(2, matches.count)
        assert_equal(c2.id, matches.all[0].id)
        assert_equal(c1.id, matches.all[1].id)
      end

      should "default to id_desc order when searched with no options specified" do
        comms = create_list(:comment, 3)
        matches = Comment.search({})

        assert_equal([comms[2].id, comms[1].id, comms[0].id], matches.map(&:id))
      end

      context "that is edited by a moderator" do
        setup do
          @post = create(:post)
          @comment = create(:comment, post_id: @post.id)
          @mod = create(:moderator_user)
          CurrentUser.user = @mod
        end

        should "create a mod action" do
          assert_difference("ModAction.count") do
            @comment.update(body: "nope")
          end
        end

        should "credit the moderator as the updater" do
          @comment.update(body: "test")
          assert_equal(@mod.id, @comment.updater_id)
        end
      end

      context "that is hidden by a moderator" do
        setup do
          @comment = create(:comment)
          @mod = create(:moderator_user)
          CurrentUser.user = @mod
        end

        should "create a mod action" do
          assert_difference(-> { ModAction.count }, 1) do
            @comment.update(is_hidden: true)
          end
        end

        should "credit the moderator as the updater" do
          @comment.update(is_hidden: true)
          assert_equal(@mod.id, @comment.updater_id)
        end
      end

      context "that is stickied by a moderator" do
        setup do
          @comment = create(:comment)
          @mod = create(:moderator_user)
          CurrentUser.user = @mod
        end

        should "create a mod action" do
          assert_difference(-> { ModAction.count }, 1) do
            @comment.update(is_sticky: true)
          end
        end

        should "credit the moderator as the updater" do
          @comment.update(is_sticky: true)
          assert_equal(@mod.id, @comment.updater_id)
        end
      end

      context "that is deleted" do
        setup do
          @comment = create(:comment)
        end

        should "create a mod action" do
          assert_difference(-> { ModAction.count }, 1) do
            @comment.destroy
          end
        end
      end

      context "that is below the score threshold" do
        should "be hidden if not stickied" do
          user = create(:user, comment_threshold: 0)
          post = create(:post)
          comment = create(:comment, post: post, score: -5)

          assert_equal([comment], post.comments.hidden(user))
          assert_equal([], post.comments.visible(user))
        end

        should "be visible if stickied" do
          user = create(:user, comment_threshold: 0)
          post = create(:post)
          comment = create(:comment, post: post, score: -5, is_sticky: true)

          assert_equal([], post.comments.hidden(user))
          assert_equal([comment], post.comments.visible(user))
        end
      end

      context "on a comment locked post" do
        setup do
          @post = create(:post, is_comment_locked: true)
        end

        should "prevent new comments" do
          comment = build(:comment, post: @post)
          comment.save
          assert_equal(["Post has comments locked"], comment.errors.full_messages)
        end
      end
    end

    context "during validation" do
      subject { build(:comment) }
      should_not allow_value(" ").for(:body)
    end
  end
end
