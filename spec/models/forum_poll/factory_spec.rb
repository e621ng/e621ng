# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                              ForumPoll Factory                              #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPoll do
  include_context "as privileged"

  it "creates a valid poll with two options" do
    poll = create(:forum_poll)
    expect(poll).to be_persisted
    expect(poll.options.count).to eq(2)
    expect(poll.options.map(&:position)).to eq([0, 1])
    expect(poll.creator).to eq(CurrentUser.user)
  end

  it "honours options_count" do
    expect(create(:forum_poll, options_count: 5).options.count).to eq(5)
  end

  it "creates options and votes" do
    vote = create(:forum_poll_vote)
    expect(vote).to be_persisted
    expect(vote.poll).to eq(vote.option.poll)
  end
end
