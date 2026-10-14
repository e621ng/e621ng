# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::UserAltsController do
  include_context "as admin"

  let(:moderator) { create(:moderator_user) }
  let(:member)    { create(:user) }
  let(:target)    { create(:user) }

  describe "GET /staff/user_alts" do
    it "redirects anonymous to the login page" do
      get staff_user_alts_path(user_id: target.id)
      expect(response).to redirect_to(new_session_path(url: staff_user_alts_path(user_id: target.id)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get staff_user_alts_path(user_id: target.id)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "returns 200" do
        get staff_user_alts_path(user_id: target.id)
        expect(response).to have_http_status(:ok)
      end

      it "renders the HTML results table with candidates present" do
        alt = create(:user)
        create(:user_ip_address, user: target, ip_addr: "203.0.113.40",
                                 first_seen_at: 30.days.ago, last_seen_at: 2.days.ago, hit_count: 10)
        create(:user_ip_address, user: alt, ip_addr: "203.0.113.40",
                                 first_seen_at: 5.days.ago, last_seen_at: 1.day.ago, hit_count: 8)

        get staff_user_alts_path(user_id: target.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(user_path(alt)) # candidate row rendered
        expect(response.body).not_to include("203.0.113")
      end

      it "renders candidates without exposing any IP or subnet value in JSON" do
        alt = create(:user)
        create(:user_ip_address, user: target, ip_addr: "203.0.113.40",
                                 first_seen_at: 30.days.ago, last_seen_at: 2.days.ago, hit_count: 10)
        create(:user_ip_address, user: alt, ip_addr: "203.0.113.40",
                                 first_seen_at: 5.days.ago, last_seen_at: 1.day.ago, hit_count: 8)

        get staff_user_alts_path(user_id: target.id, format: :json)
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body).to be_an(Array)
        expect(body.pluck("user_id")).to include(alt.id)
        body.each do |candidate|
          expect(candidate).not_to have_key("ip_addr")
          expect(candidate).not_to have_key("subnet")
          expect(candidate["user"]).not_to have_key("ip_addr")
        end
        # No IP octet leaks anywhere in the payload.
        expect(response.body).not_to include("203.0.113")
      end
    end
  end
end
