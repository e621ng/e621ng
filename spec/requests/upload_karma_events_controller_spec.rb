# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadKarmaEventsController do
  include_context "as admin"

  let(:member) { create(:user) }

  describe "GET /upload_karma_events" do
    it "returns 200 for anonymous" do
      get upload_karma_events_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a member" do
      sign_in_as member
      get upload_karma_events_path
      expect(response).to have_http_status(:ok)
    end

    it "renders rows of every reason" do
      UploadKarmaEvent.reasons.each_key do |reason|
        create(:upload_karma_event, reason: reason, post_id: 1, extra_data: { "new_owner" => 1, "new_karma" => 5 })
      end
      get upload_karma_events_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a bare JSON array with the expected fields" do
      event = create(:upload_karma_event, post_id: 123, delta: -4, balance: 6, extra_data: { "credit_reversed" => true })
      get upload_karma_events_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
      entry = response.parsed_body.find { |e| e["id"] == event.id }
      expect(entry).to include(
        "user_id" => event.user_id,
        "creator_id" => event.creator_id,
        "post_id" => 123,
        "reason" => "approved",
        "delta" => -4,
        "balance" => 6,
        "extra_data" => { "credit_reversed" => true },
      )
    end

    context "with search params" do
      let!(:event_a) { create(:upload_karma_event, post_id: 1, reason: :approved) }
      let!(:event_b) { create(:upload_karma_event, post_id: 2, reason: :deleted) }

      def returned_ids
        response.parsed_body.pluck("id")
      end

      it "filters by user_id" do
        get upload_karma_events_path(format: :json, params: { search: { user_id: event_a.user_id } })
        expect(returned_ids).to eq([event_a.id])
      end

      it "filters by user_name" do
        get upload_karma_events_path(format: :json, params: { search: { user_name: event_a.user.name } })
        expect(returned_ids).to eq([event_a.id])
      end

      it "filters by creator_id" do
        get upload_karma_events_path(format: :json, params: { search: { creator_id: event_b.creator_id } })
        expect(returned_ids).to eq([event_b.id])
      end

      it "filters by post_id" do
        get upload_karma_events_path(format: :json, params: { search: { post_id: 2 } })
        expect(returned_ids).to eq([event_b.id])
      end

      it "filters by reason" do
        get upload_karma_events_path(format: :json, params: { search: { reason: "deleted" } })
        expect(returned_ids).to eq([event_b.id])
      end
    end
  end
end
