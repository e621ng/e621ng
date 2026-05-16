# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::VoteTrendsController", type: :request do
  describe "GET /admin/vote_trends" do
    let(:target_user) { create(:user) }
    let(:member_user) { create(:user) }
    let(:admin_user) { create(:admin_user) }

    it "redirects anonymous users" do
      get admin_vote_trends_path
      expect(response).to redirect_to(new_session_path(url: admin_vote_trends_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as member_user
      get admin_vote_trends_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      it "calls VoteManager::VoteAbuseMethods with normalized params" do
        expect(VoteManager::VoteAbuseMethods).to receive(:vote_abuse_patterns).with(hash_including(
          user: an_instance_of(User),
          limit: 5,
          threshold: 0.2,
          duration: "7",
          vote_normality: true
        )).and_return([])

        sign_in_as admin_user

        get admin_vote_trends_path, params: {
          user: target_user.name,
          limit: "5",
          threshold: "0.2",
          duration: "7",
          disable_vote_normality: "0"
        }

        expect(response).to have_http_status(:ok)
      end

      # JSON behavior is covered elsewhere; ensure HTML response and call behavior above.
    end
  end
end
