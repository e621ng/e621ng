# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::VoteTrendsController" do
  describe "GET /admin/vote_trends" do
    let(:target_user) { create(:user) }
    let(:member_user) { create(:user) }
    let(:admin_user) { create(:admin_user) }

    it "redirects anonymous users" do
      get staff_vote_trends_path
      expect(response).to redirect_to(new_session_path(url: staff_vote_trends_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as member_user
      get staff_vote_trends_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      it "returns an empty result when user is missing" do
        sign_in_as admin_user

        allow(VoteTrends).to receive(:vote_abuse_patterns)

        get staff_vote_trends_path

        expect(response).to have_http_status(:ok)
        expect(VoteTrends).not_to have_received(:vote_abuse_patterns)
      end

      it "returns an empty result when user param is blank" do
        sign_in_as admin_user

        allow(VoteTrends).to receive(:vote_abuse_patterns)

        get staff_vote_trends_path, params: { user: "" }

        expect(response).to have_http_status(:ok)
        expect(VoteTrends).not_to have_received(:vote_abuse_patterns)
      end

      it "calls VoteTrends with normalized params" do
        allow(VoteTrends).to receive(:vote_abuse_patterns).and_return([])

        sign_in_as admin_user

        get staff_vote_trends_path, params: {
          user: target_user.name,
          limit: "5",
          threshold: "0.2",
          duration: "7",
          disable_vote_normality: "0",
        }

        expect(response).to have_http_status(:ok)
        expect(VoteTrends).to have_received(:vote_abuse_patterns)
          .with(hash_including(
                  user: an_instance_of(User),
                  limit: 5,
                  threshold: 0.2,
                  duration: "7",
                  vote_normality: true,
                ))
      end
    end
  end
end
