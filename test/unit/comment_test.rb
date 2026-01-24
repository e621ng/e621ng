# frozen_string_literal: true

require "test_helper"

class CommentTest < ActiveSupport::TestCase
  # =============================================================================
  # VISIBILITY AND ACCESS CONTROL TESTS
  # =============================================================================

  context "Comment.accessible" do
    setup do
      @user = create(:user)
      @other_user = create(:user)
      @janitor = create(:janitor_user)
      @moderator = create(:moderator_user)
    end

    context "with regular users" do
      should "show non-hidden comments" do
        comment = as(@user) { create(:comment, is_hidden: false) }
        assert_includes(Comment.accessible(@user), comment)
        assert(comment.is_accessible?(@user))
      end

      should "hide hidden comments when show_hidden_comments is false" do
        @user.update!(show_hidden_comments: false)
        comment = as(@user) { create(:comment, is_hidden: true) }
        assert_not_includes(Comment.accessible(@user), comment)
        assert_not(comment.is_accessible?(@user))
      end

      should "show own hidden comments when show_hidden_comments is true" do
        @user.update!(show_hidden_comments: true)
        comment = as(@user) { create(:comment, creator: @user, is_hidden: true) }
        assert_includes(Comment.accessible(@user), comment)
        assert(comment.is_accessible?(@user))
      end

      should "hide other users' hidden comments when show_hidden_comments is true" do
        @user.update!(show_hidden_comments: true)
        comment = as(@other_user) { create(:comment, creator: @other_user, is_hidden: true) }
        assert_not_includes(Comment.accessible(@user), comment)
        assert_not(comment.is_accessible?(@user))
      end

      should "hide comments on posts with disabled comments" do
        post = as(@user) { create(:post, is_comment_disabled: true) }
        comment = as(@moderator) { create(:comment, post: post) }
        assert_not_includes(Comment.accessible(@user), comment)
        assert_not(comment.is_accessible?(@user))
      end

      should "hide own comments on posts with disabled comments" do
        post = as(@user) { create(:post, is_comment_disabled: true) }
        comment = as(@moderator) { create(:comment, post: post, creator: @moderator) }
        # Moderators CAN see comments on disabled posts (they are staff)
        assert_includes(Comment.accessible(@moderator), comment)
        assert(comment.is_accessible?(@moderator))
      end
    end

    context "with anonymous users" do
      setup do
        @anon = User.anonymous
      end

      should "show non-hidden comments" do
        comment = as(@user) { create(:comment, is_hidden: false) }
        assert_includes(Comment.accessible(@anon), comment)
        assert(comment.is_accessible?(@anon))
      end

      should "hide hidden comments" do
        comment = as(@user) { create(:comment, is_hidden: true) }
        assert_not_includes(Comment.accessible(@anon), comment)
        assert_not(comment.is_accessible?(@anon))
      end

      should "hide comments on disabled posts" do
        post = as(@user) { create(:post, is_comment_disabled: true) }
        comment = as(@moderator) { create(:comment, post: post) }
        assert_not_includes(Comment.accessible(@anon), comment)
        assert_not(comment.is_accessible?(@anon))
      end
    end

    context "with janitors" do
      should "show non-hidden comments" do
        comment = as(@janitor) { create(:comment, is_hidden: false) }
        assert_includes(Comment.accessible(@janitor), comment)
        assert(comment.is_accessible?(@janitor))
      end

      should "hide hidden comments when show_hidden_comments is false" do
        @janitor.update!(show_hidden_comments: false)
        comment = as(@janitor) { create(:comment, is_hidden: true) }
        assert_not_includes(Comment.accessible(@janitor), comment)
        assert_not(comment.is_accessible?(@janitor))
      end

      should "show all hidden comments when show_hidden_comments is true" do
        @janitor.update!(show_hidden_comments: true)
        comment1 = as(@user) { create(:comment, is_hidden: true) }
        comment2 = as(@other_user) { create(:comment, is_hidden: true, creator: @other_user) }
        assert_includes(Comment.accessible(@janitor), comment1)
        assert_includes(Comment.accessible(@janitor), comment2)
        assert(comment1.is_accessible?(@janitor))
        assert(comment2.is_accessible?(@janitor))
      end

      should "show comments on disabled posts" do
        post = as(@user) { create(:post, is_comment_disabled: true) }
        comment = as(@moderator) { create(:comment, post: post) }
        assert_includes(Comment.accessible(@janitor), comment)
        assert(comment.is_accessible?(@janitor))
      end
    end

    context "with moderators" do
      should "show all hidden comments when show_hidden_comments is true" do
        @moderator.update!(show_hidden_comments: true)
        comment = as(@user) { create(:comment, is_hidden: true) }
        assert_includes(Comment.accessible(@moderator), comment)
        assert(comment.is_accessible?(@moderator))
      end

      should "show comments on disabled posts" do
        post = as(@user) { create(:post, is_comment_disabled: true) }
        comment = as(@moderator) { create(:comment, post: post) }
        assert_includes(Comment.accessible(@moderator), comment)
        assert(comment.is_accessible?(@moderator))
      end
    end

    context "with bypass_user_settings flag" do
      should "show hidden comments regardless of preference when true" do
        @user.update!(show_hidden_comments: false)
        comment = as(@user) { create(:comment, creator: @user, is_hidden: true) }
        assert_not_includes(Comment.accessible(@user), comment)
        assert_includes(Comment.accessible(@user, bypass_user_settings: true), comment)
        assert_not(comment.is_accessible?(@user))
        assert(comment.is_accessible?(@user, bypass_user_settings: true))
      end

      should "show all staff hidden comments when bypassing" do
        @janitor.update!(show_hidden_comments: false)
        comment = as(@user) { create(:comment, is_hidden: true) }
        assert_not_includes(Comment.accessible(@janitor), comment)
        assert_includes(Comment.accessible(@janitor, bypass_user_settings: true), comment)
        assert_not(comment.is_accessible?(@janitor))
        assert(comment.is_accessible?(@janitor, bypass_user_settings: true))
      end
    end
  end

  context "Comment.above_threshold" do
    setup do
      @user = create(:user, comment_threshold: 0)
    end

    should "show comments at or above threshold" do
      comment_positive = as(@user) { create(:comment, score: 5) }
      comment_zero = as(@user) { create(:comment, score: 0) }
      comment_negative = as(@user) { create(:comment, score: -1) }

      results = Comment.above_threshold(@user)
      assert_includes(results, comment_positive)
      assert_includes(results, comment_zero)
      assert_not_includes(results, comment_negative)
      assert(comment_positive.is_above_threshold?(@user))
      assert(comment_zero.is_above_threshold?(@user))
      assert_not(comment_negative.is_above_threshold?(@user))
    end

    should "show sticky comments regardless of score" do
      sticky_low_score = as(@user) { create(:comment, score: -10, is_sticky: true) }
      sticky_high_score = as(@user) { create(:comment, score: 10, is_sticky: true) }

      results = Comment.above_threshold(@user)
      assert_includes(results, sticky_low_score)
      assert_includes(results, sticky_high_score)
      assert(sticky_low_score.is_above_threshold?(@user))
      assert(sticky_high_score.is_above_threshold?(@user))
    end

    should "respect different thresholds per user" do
      user_high_threshold = create(:user, comment_threshold: 5)
      user_low_threshold = create(:user, comment_threshold: -5)
      comment_mid = as(@user) { create(:comment, score: 0) }

      assert_not_includes(Comment.above_threshold(user_high_threshold), comment_mid)
      assert_includes(Comment.above_threshold(user_low_threshold), comment_mid)
      assert_not(comment_mid.is_above_threshold?(user_high_threshold))
      assert(comment_mid.is_above_threshold?(user_low_threshold))
    end

    should "work with negative thresholds" do
      user_negative = create(:user, comment_threshold: -10)
      comment = as(@user) { create(:comment, score: -5) }
      assert_includes(Comment.above_threshold(user_negative), comment)
      assert(comment.is_above_threshold?(user_negative))
    end
  end

  context "Comment.below_threshold" do
    setup do
      @user = create(:user, comment_threshold: 0)
    end

    should "show comments below threshold" do
      comment_positive = as(@user) { create(:comment, score: 5) }
      comment_negative = as(@user) { create(:comment, score: -1) }

      results = Comment.below_threshold(@user)
      assert_not_includes(results, comment_positive)
      assert_includes(results, comment_negative)
      assert_not(comment_positive.is_below_threshold?(@user))
      assert(comment_negative.is_below_threshold?(@user))
    end

    should "exclude sticky comments regardless of score" do
      sticky_low_score = as(@user) { create(:comment, score: -10, is_sticky: true) }
      non_sticky_low_score = as(@user) { create(:comment, score: -10, is_sticky: false) }

      results = Comment.below_threshold(@user)
      assert_not_includes(results, sticky_low_score)
      assert_includes(results, non_sticky_low_score)
      assert_not(sticky_low_score.is_below_threshold?(@user))
      assert(non_sticky_low_score.is_below_threshold?(@user))
    end

    should "respect different thresholds per user" do
      user_high_threshold = create(:user, comment_threshold: 5)
      user_low_threshold = create(:user, comment_threshold: -5)
      comment_mid = as(@user) { create(:comment, score: 0) }

      assert_includes(Comment.below_threshold(user_high_threshold), comment_mid)
      assert_not_includes(Comment.below_threshold(user_low_threshold), comment_mid)
      assert(comment_mid.is_below_threshold?(user_high_threshold))
      assert_not(comment_mid.is_below_threshold?(user_low_threshold))
    end
  end

  # =============================================================================
  # SEARCH TESTS
  # =============================================================================

  context "Comment.search" do
    setup do
      @user = create(:user)
      @other_user = create(:user)
    end

    context "with body_matches" do
      should "find comments by text content" do
        c1 = as(@user) { create(:comment, body: "aaa bbb ccc") }
        c2 = as(@user) { create(:comment, body: "aaa ddd") }
        as(@user) { create(:comment, body: "eee") }

        CurrentUser.scoped(@user) do
          matches = Comment.search(body_matches: "aaa")
          assert_equal(2, matches.count)
          assert_includes(matches, c1)
          assert_includes(matches, c2)
        end
      end

      should "use subquery for non-wildcard searches" do
        as(@user) { create(:comment, body: "test content") }

        CurrentUser.scoped(@user) do
          query = Comment.search(body_matches: "test").to_sql
          assert_match(/IN \(SELECT/, query)
          assert_match(/LIMIT 10000/, query)
        end
      end

      should "not use subquery for wildcard searches" do
        as(@user) { create(:comment, body: "test content") }

        CurrentUser.scoped(@user) do
          query = Comment.search(body_matches: "test*").to_sql
          assert_no_match(/IN \(SELECT/, query)
          assert_match(/LIKE/i, query)
        end
      end

      should "support advanced search with websearch_to_tsquery" do
        cat_comment = as(@user) { create(:comment, body: "I love cats and dogs") }
        dog_only = as(@user) { create(:comment, body: "Dogs are great pets") }
        cat_only = as(@user) { create(:comment, body: "Cats are independent") }
        bird_comment = as(@user) { create(:comment, body: "Birds can fly") }

        CurrentUser.scoped(@user) do
          # Boolean AND search
          and_matches = Comment.search(body_matches: "cats AND dogs", advanced_search: true)
          assert_includes(and_matches, cat_comment)
          assert_not_includes(and_matches, dog_only)
          assert_not_includes(and_matches, cat_only)
          assert_not_includes(and_matches, bird_comment)

          # Boolean OR search
          or_matches = Comment.search(body_matches: "cats OR birds", advanced_search: true)
          assert_includes(or_matches, cat_comment)
          assert_not_includes(or_matches, dog_only)
          assert_includes(or_matches, cat_only)
          assert_includes(or_matches, bird_comment)

          # Negation search
          not_matches = Comment.search(body_matches: "pets -cats", advanced_search: true)
          assert_not_includes(not_matches, cat_comment)
          assert_includes(not_matches, dog_only)
          assert_not_includes(not_matches, cat_only)
          assert_not_includes(not_matches, bird_comment)

          # Phrase search in advanced mode
          phrase_matches = Comment.search(body_matches: '"are great"', advanced_search: true)
          assert_not_includes(phrase_matches, cat_comment)
          assert_includes(phrase_matches, dog_only)
          assert_not_includes(phrase_matches, cat_only)
          assert_not_includes(phrase_matches, bird_comment)
        end
      end

      should "fall back to quote-based logic when advanced_search is false" do
        as(@user) { create(:comment, body: "test content") }

        CurrentUser.scoped(@user) do
          unquoted_query = Comment.search(body_matches: "test content", advanced_search: false).to_sql
          assert_match(/plainto_tsquery/i, unquoted_query)
          assert_no_match(/websearch_to_tsquery/i, unquoted_query)
        end
      end

      should "handle complex boolean expressions in advanced search" do
        fox_comment = as(@user) { create(:comment, body: "I see a fox running") }
        cat_comment = as(@user) { create(:comment, body: "A lazy cat sleeps") }
        both_comment = as(@user) { create(:comment, body: "The fox and cat are friends") }
        neither_comment = as(@user) { create(:comment, body: "Just some birds flying") }

        CurrentUser.scoped(@user) do
          # Simple OR test
          or_matches = Comment.search(body_matches: "fox OR cat", advanced_search: true)
          assert_includes(or_matches, fox_comment)
          assert_includes(or_matches, cat_comment)
          assert_includes(or_matches, both_comment)
          assert_not_includes(or_matches, neither_comment)

          # Simple AND test
          and_matches = Comment.search(body_matches: "fox AND cat", advanced_search: true)
          assert_not_includes(and_matches, fox_comment) # only has fox
          assert_not_includes(and_matches, cat_comment) # only has cat
          assert_includes(and_matches, both_comment) # has both
          assert_not_includes(and_matches, neither_comment) # has neither

          # Test phrase search in advanced mode
          phrase_matches = Comment.search(body_matches: '"lazy cat"', advanced_search: true)
          assert_not_includes(phrase_matches, fox_comment)
          assert_includes(phrase_matches, cat_comment) # has "lazy cat"
          assert_not_includes(phrase_matches, both_comment) # has "cat" but not "lazy cat"
          assert_not_includes(phrase_matches, neither_comment)
        end
      end
    end

    context "with creator filtering" do
      should "filter by creator_id in main query when no body_matches" do
        c1 = as(@user) { create(:comment, creator: @user) }
        c2 = as(@other_user) { create(:comment) }

        CurrentUser.scoped(@user) do
          matches = Comment.search("creator_id" => @user.id.to_s)
          assert_includes(matches, c1)
          assert_not_includes(matches, c2)
        end
      end

      should "filter by creator_id in subquery when body_matches is present" do
        c1 = as(@user) { create(:comment, creator: @user, body: "test content") }
        c2 = as(@other_user) { create(:comment, body: "test content") }

        CurrentUser.scoped(@user) do
          matches = Comment.search("body_matches" => "test", "creator_id" => @user.id.to_s)
          assert_includes(matches, c1)
          assert_not_includes(matches, c2)
        end
      end

      should "not duplicate creator filter when used in subquery" do
        as(@user) { create(:comment, creator: @user, body: "test") }

        CurrentUser.scoped(@user) do
          query = Comment.search("body_matches" => "test", "creator_id" => @user.id.to_s).to_sql
          creator_filters = query.scan("creator_id").count
          assert_equal(1, creator_filters, "Creator filter should appear exactly once")
        end
      end
    end

    context "with post_tags_match" do
      should "find comments by post tags" do
        p1 = as(@user) { create(:post, tag_string: "aaa bbb ccc") }
        p2 = as(@user) { create(:post, tag_string: "aaa ddd") }
        p3 = as(@user) { create(:post, tag_string: "eee") }
        c1 = as(@user) { create(:comment, post: p1) }
        c2 = as(@user) { create(:comment, post: p2) }
        as(@user) { create(:comment, post: p3) }

        CurrentUser.scoped(@user) do
          matches = Comment.search(post_tags_match: "aaa")
          assert_equal(2, matches.count)
          assert_includes(matches, c1)
          assert_includes(matches, c2)
        end
      end
    end

    context "with accessible scope applied by default" do
      should "exclude hidden comments for regular users" do
        @user.update!(show_hidden_comments: false)
        CurrentUser.scoped(@user) do
          visible_comment = create(:comment, is_hidden: false)
          hidden_comment = create(:comment, is_hidden: true)

          results = Comment.search({})
          assert_includes(results, visible_comment)
          assert_not_includes(results, hidden_comment)
        end
      end

      should "exclude comments on disabled posts for regular users" do
        CurrentUser.scoped(@user) do
          normal_post = as(@user) { create(:post) }
          disabled_post = as(@other_user) { create(:post, is_comment_disabled: true) }
          normal_comment = as(@user) { create(:comment, post: normal_post) }
          # Use moderator to create comment on disabled post
          moderator = create(:moderator_user)
          disabled_comment = as(moderator) { create(:comment, post: disabled_post) }

          results = Comment.search({})
          assert_includes(results, normal_comment)
          assert_not_includes(results, disabled_comment)
        end
      end
    end

    should "default to id_desc order when no options specified" do
      comms = as(@user) { create_list(:comment, 3) }
      CurrentUser.scoped(@user) do
        matches = Comment.search({})
        assert_equal([comms[2].id, comms[1].id, comms[0].id], matches.map(&:id))
      end
    end
  end

  # =============================================================================
  # VALIDATION AND CREATION TESTS
  # =============================================================================

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
        create(:comment, do_not_bump_post: true, post: post)
        post.reload
        assert_nil(post.last_comment_bumped_at)

        create(:comment, post: post)
        post.reload
        assert_not_nil(post.last_comment_bumped_at)
      end

      should "not bump the post after exceeding the threshold" do
        Danbooru.config.stubs(:comment_threshold).returns(1)
        p = create(:post)
        c1 = create(:comment, post: p)
        travel_to(2.seconds.from_now) do
          create(:comment, post: p)
        end
        p.reload
        assert_equal(c1.created_at.to_s, p.last_comment_bumped_at.to_s)
      end

      should "update last_commented_at on the post" do
        post_creator = create(:user)
        post = as(post_creator) { create(:post) }
        Danbooru.config.stubs(:comment_threshold).returns(1)

        user = create(:user)
        c1 = as(user) { create(:comment, do_not_bump_post: true, post: post) }
        post.reload
        assert_equal(c1.created_at.to_s, post.last_commented_at.to_s)

        c2 = as(user) { create(:comment, post: post) }
        post.reload
        assert_equal(c2.created_at.to_s, post.last_commented_at.to_s)
      end

      should "not record the user id of the voter" do
        comment_creator = create(:user)
        voter = create(:user)
        post_creator = create(:user)
        post = as(post_creator) { create(:post) }
        c1 = as(comment_creator) { create(:comment, post: post) }

        as(voter) do
          VoteManager.comment_vote!(user: voter, comment: c1, score: -1)
          c1.reload
          assert_not_equal(voter.id, c1.updater_id)
        end
      end

      should "not allow duplicate votes" do
        comment_creator = create(:user)
        voter = create(:user)
        post_creator = create(:user)
        post = as(post_creator) { create(:post) }
        c1 = as(comment_creator) { create(:comment, post: post) }
        c2 = as(comment_creator) { create(:comment, post: post) }

        as(voter) do
          assert_nothing_raised { VoteManager.comment_vote!(user: voter, comment: c1, score: -1) }
          assert_equal(:need_unvote, VoteManager.comment_vote!(user: voter, comment: c1, score: -1))
          assert_equal(1, CommentVote.count)
          assert_equal(-1, CommentVote.last.score)

          assert_nothing_raised { VoteManager.comment_vote!(user: voter, comment: c2, score: -1) }
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
        post_creator = create(:user)
        post = as(post_creator) { create(:post) }
        c1 = as(user) { create(:comment, post: post, is_sticky: true) }

        exception = assert_raises(ActiveRecord::RecordInvalid) { VoteManager.comment_vote!(user: user, comment: c1, score: -1) }
        assert_match(/You cannot vote on sticky comments/, exception.message)
      end

      should "allow undoing of votes" do
        comment_creator = create(:user)
        voter = create(:user)
        post_creator = create(:user)
        post = as(post_creator) { create(:post) }
        comment = as(comment_creator) { create(:comment, post: post) }
        as(voter) do
          VoteManager.comment_vote!(user: voter, comment: comment, score: 1)
          comment.reload
          assert_equal(1, comment.score)
          VoteManager.comment_unvote!(user: voter, comment: comment)
          comment.reload
          assert_equal(0, comment.score)
          assert_nothing_raised { VoteManager.comment_vote!(user: voter, comment: comment, score: -1) }
        end
      end

      should "be searchable by body content" do
        user = create(:user)
        c1 = as(user) { create(:comment, body: "aaa bbb ccc") }
        c2 = as(user) { create(:comment, body: "aaa ddd") }
        as(user) { create(:comment, body: "eee") }

        matches = Comment.search(body_matches: "aaa")
        assert_equal(2, matches.count)
        assert_equal(c2.id, matches.all[0].id)
        assert_equal(c1.id, matches.all[1].id)
      end

      should "be searchable by post tags" do
        user = create(:user)
        p1 = as(user) { create(:post, tag_string: "aaa bbb ccc") }
        p2 = as(user) { create(:post, tag_string: "aaa ddd") }
        p3 = as(user) { create(:post, tag_string: "eee") }
        c1 = as(user) { create(:comment, post_id: p1.id, body: "comment body text") }
        c2 = as(user) { create(:comment, post_id: p2.id, body: "comment body text") }
        as(user) { create(:comment, post_id: p3.id, body: "comment body text") }

        matches = Comment.search(post_tags_match: "aaa")
        assert_equal(2, matches.count)
        assert_equal(c2.id, matches.all[0].id)
        assert_equal(c1.id, matches.all[1].id)
        assert(matches.is_a?(ActiveRecord::Relation), "Return value isn't a ActiveRecord::Relation. #{matches}")
      end

      should "be searchable by grouped post tags" do # rubocop:disable Style/MultilineIfModifier
        user = create(:user)
        p1 = as(user) { create(:post, tag_string: "aaa bbb ccc") }
        p2 = as(user) { create(:post, tag_string: "aaa ddd") }
        p3 = as(user) { create(:post, tag_string: "eee") }
        c1 = as(user) { create(:comment, post_id: p1.id, body: "comment body text") }
        c2 = as(user) { create(:comment, post_id: p2.id, body: "comment body text") }
        as(user) { create(:comment, post_id: p3.id, body: "comment body text") }

        matches = Comment.search(post_tags_match: "~( aaa bbb ) ~( ddd -( ~ccc ~eee ) )")
        assert(matches.is_a?(ActiveRecord::Relation), "Return value isn't a ActiveRecord::Relation. #{matches}")
        assert_equal(2, matches.count)
        assert_equal(c2.id, matches.all[0].id)
        assert_equal(c1.id, matches.all[1].id)
      end if PostQueryBuilder::CAN_HAVE_GROUPS

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

          assert_equal([comment], post.comments.below_threshold(user))
          assert_equal([], post.comments.above_threshold(user))
        end

        should "be visible if stickied" do
          user = create(:user, comment_threshold: 0)
          post = create(:post)
          comment = create(:comment, post: post, score: -5, is_sticky: true)

          assert_equal([], post.comments.below_threshold(user))
          assert_equal([comment], post.comments.above_threshold(user))
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

      context "on a comment disabled post" do
        setup do
          @post = create(:post, is_comment_disabled: true)
        end

        should "prevent new comments" do
          comment = build(:comment, post: @post)
          comment.save
          assert_equal(["Post has comments disabled"], comment.errors.full_messages)
        end

        should "not be accessible to any regular users" do
          user = create(:user)
          other_user = create(:user)
          post = create(:post)
          comment = create(:comment, post: post, creator: user)
          post.update!(is_comment_disabled: true)

          # No regular users can access comments on disabled posts
          assert_not_includes(Comment.accessible(user), comment)
          assert_not_includes(Comment.accessible(other_user), comment)
        end

        should "be accessible to moderators" do
          mod = create(:moderator_user)
          user = create(:user)
          post = create(:post)
          comment = create(:comment, post: post, creator: user)
          post.update!(is_comment_disabled: true)

          assert_includes(Comment.accessible(mod), comment)
        end
      end

      context "visibility filtering" do
        should "show sticky comments to all users regardless of score" do
          user = create(:user, comment_threshold: 0)
          post = create(:post)
          sticky_comment = create(:comment, post: post, score: -10, is_sticky: true)

          assert_includes(Comment.above_threshold(user), sticky_comment)
        end

        should "show own hidden comments if show_hidden_comments is true" do
          user = create(:user, show_hidden_comments: true)
          other_user = create(:user)
          post = create(:post)
          hidden_comment = create(:comment, post: post, creator: user, is_hidden: true)

          assert_includes(Comment.accessible(user), hidden_comment)
          assert_not_includes(Comment.accessible(other_user), hidden_comment)
        end

        should "hide own hidden comments if show_hidden_comments is false" do
          user = create(:user, show_hidden_comments: false)
          post = create(:post)
          hidden_comment = create(:comment, post: post, creator: user, is_hidden: true)

          assert_not_includes(Comment.accessible(user), hidden_comment)
        end

        should "hide comments below threshold for regular users" do
          user = create(:user, comment_threshold: 0)
          post = create(:post)
          low_score_comment = create(:comment, post: post, score: -5)

          assert_not_includes(Comment.above_threshold(user), low_score_comment)
        end

        should "show hidden comments to janitors when preference enabled" do
          janitor = create(:janitor_user, show_hidden_comments: true)
          post = create(:post)
          hidden_comment = create(:comment, post: post, is_hidden: true)

          assert_includes(Comment.accessible(janitor), hidden_comment)
        end

        should "hide comments for all regular users on disabled posts" do
          user = create(:user)
          other_user = create(:user)
          post = create(:post)
          comment = create(:comment, post: post, creator: user)
          post.update!(is_comment_disabled: true)

          # No regular users can access comments on disabled posts
          assert_not_includes(Comment.accessible(user), comment)
          assert_not_includes(Comment.accessible(other_user), comment)
        end
      end
    end

    context "during validation" do
      subject { build(:comment) }
      should_not allow_value(" ").for(:body)
    end
  end
end
