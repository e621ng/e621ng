# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserNameChangeRequest do
  include_context "as member"

  # Each record needs a distinct user because apply! changes the user's name on create.
  let!(:request_alpha) do
    user = create(:user, name: "alpha_user")
    create(:user_name_change_request, user: user, original_name: "alpha_user", desired_name: "alpha_new")
  end

  let!(:request_beta) do
    user = create(:user, name: "beta_user")
    create(:user_name_change_request, user: user, original_name: "beta_user", desired_name: "beta_new")
  end

  describe ".search" do
    describe "original_name param" do
      it "returns records matching the original_name exactly" do
        results = UserNameChangeRequest.search(original_name: "alpha_user")
        expect(results).to include(request_alpha)
        expect(results).not_to include(request_beta)
      end

      it "matches case-insensitively" do
        results = UserNameChangeRequest.search(original_name: "ALPHA_USER")
        expect(results).to include(request_alpha)
      end

      it "normalises spaces to underscores (via User.normalize_name)" do
        results = UserNameChangeRequest.search(original_name: "alpha user")
        expect(results).to include(request_alpha)
      end

      it "returns no records when original_name does not match anything" do
        expect(UserNameChangeRequest.search(original_name: "nonexistent")).to be_empty
      end
    end

    describe "desired_name param" do
      it "returns records matching the desired_name exactly" do
        results = UserNameChangeRequest.search(desired_name: "alpha_new")
        expect(results).to include(request_alpha)
        expect(results).not_to include(request_beta)
      end

      it "matches case-insensitively" do
        results = UserNameChangeRequest.search(desired_name: "ALPHA_NEW")
        expect(results).to include(request_alpha)
      end

      it "returns no records when desired_name does not match anything" do
        expect(UserNameChangeRequest.search(desired_name: "nonexistent")).to be_empty
      end
    end

    describe "with no params" do
      it "returns all records" do
        results = UserNameChangeRequest.search({})
        expect(results).to include(request_alpha, request_beta)
      end
    end
  end
end
