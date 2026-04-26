# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostEventsController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:post_record) { create(:post) }
  let(:member) { create(:user) }
  let(:moderator) { create(:moderator_user) }

  describe "GET /post_events" do
    it "returns 200 for anonymous" do
      get post_events_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a member" do
      sign_in_as member
      get post_events_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON body with a post_events key" do
      create(:post_event, post_id: post_record.id)
      get post_events_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to have_key("post_events")
      expect(response.parsed_body["post_events"]).to be_an(Array)
    end

    it "serializes expected fields" do
      event = create(:post_event, post_id: post_record.id, action: :deleted)
      get post_events_path(format: :json)
      entry = response.parsed_body["post_events"].find { |e| e["id"] == event.id }
      expect(entry).to include("id", "post_id", "action", "created_at", "creator_id")
    end

    context "when the event is a flag_created" do
      it "hides creator_id from anonymous users" do
        event = create(:post_event, post_id: post_record.id, action: :flag_created)
        get post_events_path(format: :json)
        entry = response.parsed_body["post_events"].find { |e| e["id"] == event.id }
        expect(entry["creator_id"]).to be_nil
      end

      it "shows creator_id to moderators" do
        sign_in_as moderator
        event = create(:post_event, post_id: post_record.id, action: :flag_created)
        get post_events_path(format: :json)
        entry = response.parsed_body["post_events"].find { |e| e["id"] == event.id }
        expect(entry["creator_id"]).to eq(event.creator_id)
      end
    end

    context "with search params" do
      let(:other_post) { create(:post) }
      let!(:event_a) { create(:post_event, post_id: post_record.id, action: :deleted) }
      let!(:event_b) { create(:post_event, post_id: other_post.id, action: :approved) }

      it "filters by post_id" do
        get post_events_path(format: :json, params: { search: { post_id: post_record.id } })
        ids = response.parsed_body["post_events"].pluck("id")
        expect(ids).to include(event_a.id)
        expect(ids).not_to include(event_b.id)
      end

      it "filters by action" do
        get post_events_path(format: :json, params: { search: { action: "deleted" } })
        ids = response.parsed_body["post_events"].pluck("id")
        expect(ids).to include(event_a.id)
        expect(ids).not_to include(event_b.id)
      end

      it "filters by creator_id" do
        get post_events_path(format: :json, params: { search: { creator_id: event_a.creator_id } })
        ids = response.parsed_body["post_events"].pluck("id")
        expect(ids).to include(event_a.id)
        expect(ids).not_to include(event_b.id)
      end
    end

    context "when searching by a mod-only action" do
      let!(:event) { create(:post_event, post_id: post_record.id, action: :comment_locked) }

      it "returns 403 for a member" do
        sign_in_as member
        get post_events_path(format: :json, params: { search: { action: "comment_locked" } })
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 for anonymous" do
        get post_events_path(format: :json, params: { search: { action: "comment_locked" } })
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 for a moderator" do
        sign_in_as moderator
        get post_events_path(format: :json, params: { search: { action: "comment_locked" } })
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["post_events"].pluck("id")).to include(event.id)
      end
    end
  end
end
