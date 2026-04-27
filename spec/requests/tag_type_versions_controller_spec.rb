# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagTypeVersionsController do
  let(:user)  { create(:user) }
  let(:user2) { create(:user) }

  describe "#index" do
    let(:tag_a)     { create(:tag) }
    let(:tag_b)     { create(:tag) }
    let!(:version_a) { create(:tag_type_version, tag: tag_a, creator: user) }
    let!(:version_b) { create(:tag_type_version, tag: tag_b, creator: user2) }

    it "renders successfully as JSON" do
      get tag_type_versions_path(format: :json)
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck("id")).to include(version_a.id, version_b.id)
    end

    it "renders successfully as HTML" do
      get_auth tag_type_versions_path, user
      expect(response).to have_http_status(:success)
    end

    context "with tag param" do
      it "returns only versions for the given tag" do
        get tag_type_versions_path(format: :json, params: { search: { tag: tag_a.name } })
        expect(response.parsed_body.pluck("id")).to include(version_a.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_b.id)
      end
    end

    context "with user_id param" do
      it "returns only versions created by the given user" do
        get tag_type_versions_path(format: :json, params: { search: { user_id: user2.id } })
        expect(response.parsed_body.pluck("id")).to include(version_b.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_a.id)
      end
    end

    context "with user_name param" do
      it "returns only versions created by the named user" do
        get tag_type_versions_path(format: :json, params: { search: { user_name: user2.name } })
        expect(response.parsed_body.pluck("id")).to include(version_b.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_a.id)
      end
    end
  end
end
