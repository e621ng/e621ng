# frozen_string_literal: true

require "rails_helper"

RSpec.describe Moderator::AltLookupsController do
  let(:admin)     { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }
  let(:member)    { create(:user) }
  let(:target)    { create(:user) }

  before { Setting.alt_detection_enabled = true }

  describe "GET /moderator/alt_lookups/new" do
    it "redirects anonymous to the login page" do
      get new_moderator_alt_lookup_path
      expect(response).to redirect_to(new_session_path(url: new_moderator_alt_lookup_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get new_moderator_alt_lookup_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get new_moderator_alt_lookup_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get new_moderator_alt_lookup_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /moderator/alt_lookups" do
    before { sign_in_as moderator }

    it "returns 200 for a known user" do
      get moderator_alt_lookups_path, params: { user_name: target.name }
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for an unknown user" do
      get moderator_alt_lookups_path, params: { user_name: "no-such-user" }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 503 when alt detection is disabled" do
      Setting.alt_detection_enabled = false
      get moderator_alt_lookups_path, params: { user_name: target.name }
      expect(response).to have_http_status(:service_unavailable)
    end

    it "returns 403 for a member" do
      sign_in_as member
      get moderator_alt_lookups_path, params: { user_name: target.name }
      expect(response).to have_http_status(:forbidden)
    end

    it "is reachable as an admin" do
      sign_in_as admin
      get moderator_alt_lookups_path, params: { user_name: target.name }
      expect(response).to have_http_status(:ok)
    end

    it "does not include any IP addresses in the rendered page" do
      ip = "192.0.2.50"
      UserIpTouch.record_touches!([
        { user_id: target.id,    ip_addr: ip, source: "comment", last_seen_at: 1.day.ago, hit_count: 1 },
        { user_id: create(:user).id, ip_addr: ip, source: "comment", last_seen_at: 1.day.ago, hit_count: 1 },
      ])
      IpAddrStat.recompute_for!([ip])
      get moderator_alt_lookups_path, params: { user_name: target.name }
      expect(response.body).not_to include(ip)
    end
  end

  describe "throttling" do
    before do
      sign_in_as moderator
      allow(RateLimiter).to receive(:check_limit).and_return(true)
    end

    it "returns 429 when the rate limit is exceeded" do
      get moderator_alt_lookups_path, params: { user_name: target.name }
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
