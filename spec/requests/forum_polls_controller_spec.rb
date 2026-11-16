# frozen_string_literal: true

require "rails_helper"

# Routes:
#   GET    /forum_topics/:forum_topic_id/poll        forum_polls#show
#   PUT    /forum_topics/:forum_topic_id/poll        forum_polls#update
#   DELETE /forum_topics/:forum_topic_id/poll        forum_polls#destroy
#   POST   /forum_topics/:forum_topic_id/poll/close  forum_polls#close

RSpec.describe ForumPollsController do
  include_context "validating JSON"

  let(:creator) { create(:privileged_user) }
  let(:member) { create(:user, created_at: 2.weeks.ago) }
  let(:moderator) { create(:moderator_user) }
  let(:admin) { create(:admin_user) }
  let(:poll) { CurrentUser.scoped(creator) { create(:forum_poll, options_count: 2, duration: "1d") } }
  let(:topic) { poll.topic }

  before do
    CurrentUser.user = creator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  describe "show action" do
    it "renders the poll as JSON for anyone who can see the topic" do
      sign_in_as member
      get forum_topic_poll_path(topic, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to match_json_format(
        {
          id: Integer, forum_topic_id: Integer, creator_id: Integer, max_choices: Integer, expires_at: DateTime,
          closed_early_by_id: Integer, voter_count: Integer, created_at: DateTime, updated_at: DateTime, is_open: TrueClass,
          options: Array,
        },
        %i[closed_early_by_id],
      )
      expect(response.parsed_body["options"].first.keys).to contain_exactly("id", "position", "body", "vote_count")
    end

    it "redirects the HTML form to the topic" do
      sign_in_as member
      get forum_topic_poll_path(topic)
      expect(response).to redirect_to(forum_topic_path(topic))
    end

    it "404s when the topic has no poll" do
      bare = create(:forum_topic)
      sign_in_as member
      get forum_topic_poll_path(bare, format: :json)
      expect(response).to have_http_status(:not_found)
    end

    context "ballot visibility" do
      before { poll.cast_ballot!(member, [poll.options.first.id], ip_addr: "10.1.2.3") }

      it "hides voters from members" do
        sign_in_as member
        get forum_topic_poll_path(topic, format: :json)
        expect(response.parsed_body["options"].first).not_to have_key("voters")
      end

      it "shows voters without IPs to moderators" do
        sign_in_as moderator
        get forum_topic_poll_path(topic, format: :json)
        voters = response.parsed_body["options"].first["voters"]
        expect(voters.first).to include("user_id" => member.id, "user_name" => member.name)
        expect(voters.first).not_to have_key("user_ip_addr")
      end

      it "shows IPs to admins" do
        sign_in_as admin
        get forum_topic_poll_path(topic, format: :json)
        expect(response.parsed_body["options"].first["voters"].first["user_ip_addr"]).to eq("10.1.2.3")
      end
    end
  end

  describe "update action" do
    let(:new_attrs) do
      { forum_poll: { max_choices: 2, options_attributes: [{ id: poll.options.first.id, body: "Renamed" }, { body: "Third" }] } }
    end

    it "lets the creator edit an unvoted poll" do
      sign_in_as creator
      put forum_topic_poll_path(topic, format: :json), params: new_attrs
      expect(response).to have_http_status(:ok)
      expect(poll.reload.max_choices).to eq(2)
      expect(poll.options.map(&:body)).to eq(["Renamed", "Option 2", "Third"])
    end

    it "removes options flagged for destruction" do
      sign_in_as creator
      put forum_topic_poll_path(topic), params: { forum_poll: { options_attributes: [{ id: poll.options.last.id, _destroy: "1" }] } }
      expect(response).to redirect_to(forum_topic_path(topic))
      expect(poll.options.reload.map(&:body)).to eq(["Option 1"])
    end

    it "returns validation errors" do
      sign_in_as creator
      put forum_topic_poll_path(topic, format: :json), params: { forum_poll: { max_choices: 5 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Max choices cannot exceed the number of options")
    end

    it "ignores duration" do
      sign_in_as creator
      put forum_topic_poll_path(topic, format: :json), params: { forum_poll: { duration: "30d" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "is frozen after the first vote" do
      poll.cast_ballot!(member, [poll.options.first.id])
      sign_in_as creator
      put forum_topic_poll_path(topic, format: :json), params: new_attrs
      expect(response).to have_http_status(:forbidden)
    end

    it "is denied to moderators who are not the creator" do
      sign_in_as moderator
      put forum_topic_poll_path(topic, format: :json), params: new_attrs
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "close action" do
    it "lets the creator close without a mod action" do
      sign_in_as creator
      expect { post close_forum_topic_poll_path(topic) }.not_to change(ModAction, :count)
      expect(response).to redirect_to(forum_topic_path(topic))
      expect(poll.reload).not_to be_open
      expect(poll.closed_early_by).to eq(creator)
    end

    it "lets a moderator close and logs it" do
      sign_in_as moderator
      expect { post close_forum_topic_poll_path(topic, format: :json) }.to change { ModAction.where(action: "forum_poll_close").count }.by(1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_open"]).to be(false)
    end

    it "is denied to members" do
      sign_in_as member
      post close_forum_topic_poll_path(topic, format: :json)
      expect(response).to have_http_status(:forbidden)
      expect(poll.reload).to be_open
    end

    it "is denied once closed" do
      poll.close!(by: creator)
      sign_in_as creator
      post close_forum_topic_poll_path(topic, format: :json)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "destroy action" do
    it "is admin only" do
      sign_in_as moderator
      delete forum_topic_poll_path(topic, format: :json)
      expect(response).to have_http_status(:forbidden)
      expect(ForumPoll.exists?(poll.id)).to be(true)
    end

    it "deletes the poll, keeps the topic and logs a mod action" do
      poll.cast_ballot!(member, [poll.options.first.id])
      sign_in_as admin
      expect { delete forum_topic_poll_path(topic, format: :json) }.to change { ModAction.where(action: "forum_poll_delete").count }.by(1)
      expect(response).to have_http_status(:no_content)
      expect(ForumPoll.exists?(poll.id)).to be(false)
      expect(ForumPollVote.where(forum_poll_id: poll.id)).to be_empty
      expect(ForumTopic.exists?(topic.id)).to be(true)
    end
  end

  describe "lockdown" do
    it "blocks edits for non-staff when forums are disabled" do
      allow(Security::Lockdown).to receive(:forums_disabled?).and_return(true)
      sign_in_as creator
      post close_forum_topic_poll_path(topic, format: :json)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
