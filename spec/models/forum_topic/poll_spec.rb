# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ForumTopic Poll Attachment                        #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  include_context "as privileged"

  let(:poll_attributes) do
    { duration: "7d", max_choices: 1, options_attributes: [{ body: "Yes" }, { body: "No" }] }
  end

  it "creates the poll together with the topic" do
    topic = create(:forum_topic, poll_attributes: poll_attributes)
    expect(topic.poll).to be_persisted
    expect(topic.poll.creator).to eq(CurrentUser.user)
    expect(topic.poll.options.map(&:body)).to eq(%w[Yes No])
    expect(topic.as_json["poll_id"]).to eq(topic.poll.id)
  end

  it "fails the topic when the poll is invalid" do
    topic = build(:forum_topic, poll_attributes: poll_attributes.merge(options_attributes: [{ body: "" }]))
    expect(topic.save).to be(false)
    expect(topic.errors.full_messages).to include("Poll option can't be blank")
    expect(ForumTopic.where(title: topic.title)).to be_empty
  end

  it "surfaces poll-level errors verbatim" do
    topic = build(:forum_topic, poll_attributes: poll_attributes.merge(duration: "bogus"))
    expect(topic.save).to be(false)
    expect(topic.errors.full_messages).to include("Duration is not one of the allowed presets")
  end

  it "treats empty poll_attributes as no poll" do
    topic = create(:forum_topic, poll_attributes: {})
    expect(topic.poll).to be_nil
    expect(topic.as_json["poll_id"]).to be_nil
  end

  it "destroys the poll, its options and votes with the topic" do
    topic = create(:forum_topic, poll_attributes: poll_attributes)
    topic.poll.cast_ballot!(create(:user, created_at: 2.weeks.ago), [topic.poll.options.first.id])
    poll_id = topic.poll.id
    topic.destroy!
    expect(ForumPoll.where(id: poll_id)).to be_empty
    expect(ForumPollOption.where(forum_poll_id: poll_id)).to be_empty
    expect(ForumPollVote.where(forum_poll_id: poll_id)).to be_empty
  end
end
