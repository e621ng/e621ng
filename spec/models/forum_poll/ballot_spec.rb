# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          ForumPoll#cast_ballot!                             #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPoll do
  include_context "as privileged"

  let(:poll) { create(:forum_poll, options_count: 3, max_choices: 2, duration: "1d") }
  let(:a) { poll.options[0] }
  let(:b) { poll.options[1] }
  let(:c) { poll.options[2] }
  let(:voter) { create(:user, created_at: 2.weeks.ago) }
  let(:other) { create(:user, created_at: 2.weeks.ago) }

  def counts
    poll.options.reload.map(&:vote_count)
  end

  it "records a first ballot" do
    poll.cast_ballot!(voter, [a.id, b.id], ip_addr: "10.0.0.1")
    expect(counts).to eq([1, 1, 0])
    expect(poll.voter_count).to eq(1)
    expect(poll.selected_option_ids(voter)).to contain_exactly(a.id, b.id)
    expect(poll.votes.pluck(:user_ip_addr).map(&:to_s)).to all(eq("10.0.0.1"))
    expect(poll.votes.distinct.count(:created_at)).to eq(1)
  end

  it "replaces a ballot, diffing rows and counters" do
    poll.cast_ballot!(voter, [a.id, b.id])
    poll.cast_ballot!(voter, [b.id, c.id])
    expect(counts).to eq([0, 1, 1])
    expect(poll.voter_count).to eq(1)
    expect(poll.selected_option_ids(voter)).to contain_exactly(b.id, c.id)
  end

  it "withdraws a ballot with the empty set" do
    poll.cast_ballot!(voter, [a.id])
    poll.cast_ballot!(voter, [])
    expect(counts).to eq([0, 0, 0])
    expect(poll.voter_count).to eq(0)
    expect(poll.votes.where(user_id: voter.id)).to be_empty
  end

  it "counts voters, not votes" do
    poll.cast_ballot!(voter, [a.id, b.id])
    poll.cast_ballot!(other, [a.id])
    expect(counts).to eq([2, 1, 0])
    expect(poll.voter_count).to eq(2)
    expect(a.reload.percentage(poll.voter_count)).to eq(100)
    expect(b.reload.percentage(poll.voter_count)).to eq(50)
  end

  it "ignores duplicate and blank ids" do
    poll.cast_ballot!(voter, [a.id, a.id.to_s, "", nil])
    expect(counts).to eq([1, 0, 0])
  end

  it "rejects more than max_choices" do
    expect { poll.cast_ballot!(voter, [a.id, b.id, c.id]) }.to raise_error(ForumPoll::BallotError, /at most 2 options/)
    expect(counts).to eq([0, 0, 0])
  end

  it "rejects options from another poll" do
    foreign = create(:forum_poll).options.first
    expect { poll.cast_ballot!(voter, [foreign.id]) }.to raise_error(ForumPoll::BallotError, "Invalid option")
  end

  it "rejects a closed poll but leaves the frozen ballot intact" do
    poll.cast_ballot!(voter, [a.id])
    travel_to(poll.expires_at + 1.minute) do
      expect { poll.cast_ballot!(voter, [b.id]) }.to raise_error(ForumPoll::BallotError, "This poll has closed")
      expect { poll.cast_ballot!(voter, []) }.to raise_error(ForumPoll::BallotError)
    end
    expect(counts).to eq([1, 0, 0])
  end

  it "rejects accounts younger than 7 days" do
    newbie = create(:user, created_at: 3.days.ago)
    expect { poll.cast_ballot!(newbie, [a.id]) }.to raise_error(ForumPoll::BallotError, /Account is too new/)
  end

  it "enforces forum_poll_vote_limit per standing ballot, not per row" do
    allow(Danbooru.config.custom_configuration).to receive(:forum_poll_vote_limit).and_return(1)
    poll.cast_ballot!(voter, [a.id, b.id])
    second = create(:forum_poll, duration: "1d")
    expect { second.cast_ballot!(voter, [second.options.first.id]) }.to raise_error(ForumPoll::BallotError, /hourly limit/)
    # Withdrawing is never throttled
    expect { poll.cast_ballot!(voter, []) }.not_to raise_error
  end

  it "exempts staff from the throttle and newbie window" do
    allow(Danbooru.config.custom_configuration).to receive(:forum_poll_vote_limit).and_return(0)
    staff = create(:janitor_user, created_at: 1.hour.ago)
    expect { poll.cast_ballot!(staff, [a.id]) }.not_to raise_error
  end

  it "turns a unique-index collision into a user-facing error" do
    allow(ForumPollVote).to receive(:insert_all).and_raise(ActiveRecord::RecordNotUnique)
    expect { poll.cast_ballot!(voter, [a.id]) }.to raise_error(ForumPoll::BallotError, /try again/)
    expect(counts).to eq([0, 0, 0])
    expect(poll.reload.voter_count).to eq(0)
  end
end
