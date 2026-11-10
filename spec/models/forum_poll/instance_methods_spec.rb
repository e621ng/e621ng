# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          ForumPoll Instance Methods                         #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPoll do
  include_context "as privileged"

  let(:creator) { CurrentUser.user }
  let(:poll) { create(:forum_poll, duration: "1d") }
  let(:member) { create(:user, created_at: 2.weeks.ago) }
  let(:moderator) { create(:moderator_user) }
  let(:admin) { create(:admin_user) }

  describe "#open?" do
    it "flips exactly at expires_at" do
      # travel_to drops sub-second precision, so create the poll on a whole second
      poll = travel_to(Time.zone.parse("2026-11-10 12:00:00")) { create(:forum_poll, duration: "1d") }
      travel_to(poll.expires_at - 1.second) { expect(poll).to be_open }
      travel_to(poll.expires_at) { expect(poll).not_to be_open }
    end
  end

  describe "#has_embeds?" do
    it "detects thumb embeds in any option" do
      expect(poll).not_to have_embeds
      poll.options.first.update!(body: "Entry: thumb #123")
      expect(poll.reload).to have_embeds
    end
  end

  describe "#can_edit?" do
    it "allows the creator while nobody has voted" do
      expect(poll.can_edit?(creator)).to be(true)
      expect(poll.can_edit?(moderator)).to be(false)
      expect(poll.can_edit?(member)).to be(false)
    end

    it "freezes after the first vote" do
      poll.cast_ballot!(member, [poll.options.first.id])
      expect(poll.can_edit?(creator)).to be(false)
    end

    it "is false once closed" do
      travel_to(poll.expires_at + 1.second) { expect(poll.can_edit?(creator)).to be(false) }
    end
  end

  describe "#can_close?" do
    it "allows the creator and moderators on an open poll" do
      expect(poll.can_close?(creator)).to be(true)
      expect(poll.can_close?(moderator)).to be(true)
      expect(poll.can_close?(member)).to be(false)
    end

    it "is false once closed" do
      travel_to(poll.expires_at + 1.second) { expect(poll.can_close?(creator)).to be(false) }
    end
  end

  describe "#can_destroy?" do
    it "is admin only" do
      expect(poll.can_destroy?(admin)).to be(true)
      expect(poll.can_destroy?(moderator)).to be(false)
      expect(poll.can_destroy?(creator)).to be(false)
    end
  end

  describe "#close!" do
    it "closes immediately and records who did it" do
      poll.close!(by: moderator)
      expect(poll.reload).not_to be_open
      expect(poll.closed_early_by).to eq(moderator)
    end

    it "logs a mod action only when closed by someone other than the creator" do
      expect { poll.close!(by: creator) }.not_to change(ModAction, :count)
      other = create(:forum_poll, duration: "1d")
      expect { other.close!(by: moderator) }.to change { ModAction.where(action: "forum_poll_close").count }.by(1)
      expect(ModAction.last.values).to include("forum_topic_id" => other.forum_topic_id, "user_id" => creator.id)
    end

    it "refuses to close twice" do
      poll.close!(by: creator)
      expect { poll.close!(by: creator) }.to raise_error(ForumPoll::BallotError)
    end
  end

  describe "#vote_denial_reason" do
    it "requires a member" do
      expect(poll.vote_denial_reason(User.anonymous)).to eq("Log in to vote")
    end

    it "rejects closed polls" do
      travel_to(poll.expires_at + 1.second) { expect(poll.vote_denial_reason(member)).to eq("This poll has closed") }
    end

    it "rejects new accounts" do
      newbie = create(:user, created_at: 1.day.ago)
      expect(poll.vote_denial_reason(newbie)).to include("Account is too new")
    end

    it "is nil for an eligible member" do
      expect(poll.vote_denial_reason(member)).to be_nil
      expect(poll.can_vote?(member)).to be(true)
    end
  end
end
