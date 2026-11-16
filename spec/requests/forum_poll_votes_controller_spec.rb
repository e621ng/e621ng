# frozen_string_literal: true

require "rails_helper"

# Routes:
#   GET    /forum_topics/:forum_topic_id/poll/vote  forum_poll_votes#show
#   PUT    /forum_topics/:forum_topic_id/poll/vote  forum_poll_votes#update
#   DELETE /forum_topics/:forum_topic_id/poll/vote  forum_poll_votes#destroy

RSpec.describe ForumPollVotesController do
  let(:creator) { create(:privileged_user) }
  let(:voter) { create(:user, created_at: 2.weeks.ago) }
  let(:poll) { CurrentUser.scoped(creator) { create(:forum_poll, options_count: 3, max_choices: 2, duration: "1d") } }
  let(:topic) { poll.topic }
  let(:a) { poll.options[0] }
  let(:b) { poll.options[1] }
  let(:c) { poll.options[2] }

  before do
    CurrentUser.user = creator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  describe "show action" do
    it "returns the caller's own selection" do
      poll.cast_ballot!(voter, [a.id])
      sign_in_as voter
      get forum_topic_poll_vote_path(topic, format: :json)
      expect(response.parsed_body).to eq("option_ids" => [a.id])
    end
  end

  describe "update action" do
    it "requires login" do
      put forum_topic_poll_vote_path(topic), params: { option_ids: [a.id] }
      expect(response).to redirect_to(new_session_path)
    end

    it "casts a ballot and redirects for HTML" do
      sign_in_as voter
      put forum_topic_poll_vote_path(topic), params: { option_ids: [a.id, b.id] }
      expect(response).to redirect_to(forum_topic_path(topic))
      expect(poll.reload.voter_count).to eq(1)
      expect(poll.options.map(&:vote_count)).to eq([1, 1, 0])
    end

    it "returns the re-rendered poll for JSON" do
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["option_ids"]).to eq([a.id])
      expect(body["html"]).to include('id="forum-poll"', "Update vote", 'data-selected="true"')
      expect(body["html"]).not_to include("forum-poll-ballots")
      expect(body["posts"]).to eq({})
    end

    it "includes the collapsed ballot table for moderators, with IPs for admins" do
      poll.cast_ballot!(voter, [a.id, b.id], ip_addr: "10.1.2.3")
      moderator = create(:moderator_user)
      sign_in_as moderator
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [c.id] }
      html = Nokogiri::HTML.fragment(response.parsed_body["html"])
      details = html.at_css("details.forum-poll-ballots")
      expect(details).to be_present
      expect(details["open"]).to be_nil
      expect(details.css("tr.forum-poll-ballot-row").size).to eq(2)
      expect(details.text).to include(voter.pretty_name, moderator.pretty_name, "#1 Option 1, #2 Option 2")
      expect(details.text).not_to include("10.1.2.3")

      sign_in_as create(:admin_user)
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response.parsed_body["html"]).to include("10.1.2.3", "staff/ip_addrs")
    end

    it "includes deferred posts when an option embeds one" do
      post = create(:post)
      a.update!(body: "Entry: thumb ##{post.id}")
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response.parsed_body["posts"].keys).to eq([post.id.to_s])
    end

    it "replaces an existing ballot" do
      poll.cast_ballot!(voter, [a.id, b.id])
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [c.id] }
      expect(poll.options.reload.map(&:vote_count)).to eq([0, 0, 1])
      expect(poll.reload.voter_count).to eq(1)
    end

    it "lets the creator vote in their own poll" do
      sign_in_as creator
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:ok)
    end

    it "still votes on a locked topic" do
      topic.update_columns(is_locked: true)
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:ok)
    end

    it "rejects an empty selection instead of withdrawing" do
      poll.cast_ballot!(voter, [a.id])
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [""] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq("Select at least one option")
      expect(poll.reload.voter_count).to eq(1)
    end

    it "rejects more than max_choices" do
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id, b.id, c.id] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to include("at most 2 options")
    end

    it "rejects a foreign option id" do
      foreign = CurrentUser.scoped(creator) { create(:forum_poll) }.options.first
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [foreign.id] }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a closed poll" do
      poll.close!(by: creator)
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq("This poll has closed")
    end

    it "rejects new accounts" do
      newbie = create(:user, created_at: 2.days.ago)
      sign_in_as newbie
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to include("too new")
    end

    it "honours the votes lockdown for non-staff" do
      allow(Security::Lockdown).to receive(:votes_disabled?).and_return(true)
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:forbidden)

      sign_in_as create(:janitor_user)
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:ok)
    end

    it "honours the forums lockdown" do
      allow(Security::Lockdown).to receive(:forums_disabled?).and_return(true)
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:forbidden)
    end

    it "requires access to the topic" do
      topic.category.update_columns(can_view: UserLevel::MODERATOR)
      sign_in_as voter
      put forum_topic_poll_vote_path(topic, format: :json), params: { option_ids: [a.id] }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "destroy action" do
    it "withdraws the ballot" do
      poll.cast_ballot!(voter, [a.id, b.id])
      sign_in_as voter
      delete forum_topic_poll_vote_path(topic, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["option_ids"]).to eq([])
      expect(poll.reload.voter_count).to eq(0)
      expect(poll.options.map(&:vote_count)).to eq([0, 0, 0])
    end

    it "is a no-op without a ballot" do
      sign_in_as voter
      delete forum_topic_poll_vote_path(topic)
      expect(response).to redirect_to(forum_topic_path(topic))
      expect(poll.reload.voter_count).to eq(0)
    end
  end
end
