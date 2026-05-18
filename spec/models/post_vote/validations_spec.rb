# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVote do
  include_context "as admin"

  it_behaves_like "user_vote score validation", :post_vote, PostVote

  # -------------------------------------------------------------------------
  # validate_user_can_vote (PostVote-specific)
  # -------------------------------------------------------------------------
  describe "validate_user_can_vote" do
    describe "age check for downvotes" do
      before do
        # Ensure the age check is active for this group of examples.
        allow(Danbooru.config.custom_configuration).to receive(:disable_age_checks?).and_return(false)
      end

      it "is invalid when the user is younger than 3 days and downvoting" do
        young_user = create(:user, created_at: 1.day.ago)
        vote = build(:post_vote, user: young_user, score: -1)
        expect(vote).not_to be_valid
        expect(vote.errors[:user]).to be_present
      end

      it "is valid when the user is older than 3 days and downvoting" do
        old_user = create(:user, created_at: 4.days.ago)
        vote = build(:post_vote, user: old_user, score: -1)
        expect(vote).to be_valid
      end

      it "does not apply the age check for upvotes" do
        young_user = create(:user, created_at: 1.day.ago)
        vote = build(:post_vote, user: young_user, score: 1)
        expect(vote).to be_valid
      end
    end

    describe "throttle limit" do
      it "is invalid when the user has reached the post vote limit" do
        voter = create(:user)
        allow(voter).to receive(:can_post_vote_with_reason).and_return(:REJ_LIMITED)
        vote = build(:post_vote, user: voter, score: 1)
        expect(vote).not_to be_valid
        expect(vote.errors[:user]).to be_present
      end

      it "is valid when the user is within the post vote limit" do
        voter = create(:user)
        allow(voter).to receive(:can_post_vote_with_reason).and_return(true)
        vote = build(:post_vote, user: voter, score: 1)
        expect(vote).to be_valid
      end
    end
  end
end
