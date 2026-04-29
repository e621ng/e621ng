# frozen_string_literal: true

require "test_helper"

class ForumPostVotesControllerTest < ActionDispatch::IntegrationTest
  context "The forum post votes controller" do
    setup do
      @user1 = create(:user)
      @user2 = create(:user)
      CurrentUser.user = @user1

      as @user1 do
        @forum_topic = create(:forum_topic, original_post_attributes: { body: "alias" })
        @forum_post = @forum_topic.original_post
      end
    end

    context "without a tag change request" do
      should "not allow voting" do
        post_auth forum_post_votes_path(forum_post_id: @forum_post.id), @user1, params: { forum_post_vote: { score: 1 }, format: :json }
        assert_response :forbidden
      end
    end

    context "with an already accepted tag change request" do
      should "not allow voting" do
        @alias = create(:tag_alias, forum_post: @forum_post)
        post_auth forum_post_votes_path(forum_post_id: @forum_post.id), @user1, params: { forum_post_vote: { score: 1 }, format: :json }
        assert_response :forbidden
      end
    end

    context "with a pending tag change request" do
      setup do
        as @user1 do
          create(:tag_alias, status: "pending", forum_post: @forum_post)
        end
      end

      should "allow voting" do
        assert_difference(-> { ForumPostVote.count }, 1) do
          post_auth forum_post_votes_path(forum_post_id: @forum_post.id), @user2, params: { forum_post_vote: { score: 1 }, format: :json }
        end
        assert_response :success
      end

      should "not allow voting for the user who created the request" do
        assert_no_difference(-> { ForumPostVote.count }) do
          post_auth forum_post_votes_path(forum_post_id: @forum_post.id), @user1, params: { forum_post_vote: { score: 1 }, format: :json }
        end
        assert_response :forbidden
      end

      context "when deleting" do
        setup do
          as(@user2) do
            @forum_post_vote = @forum_post.votes.create(score: 1)
          end
        end

        should "allow removal" do
          assert_difference(-> { ForumPostVote.count }, -1) do
            delete_auth forum_post_votes_path(forum_post_id: @forum_post.id), @user2, params: { format: :json }
          end
          assert_response :success
        end
      end
    end
  end
end
