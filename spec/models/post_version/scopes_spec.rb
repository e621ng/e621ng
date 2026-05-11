# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersion do
  include_context "as admin"

  describe "scopes" do
    describe ".for_user" do
      let(:user_a) { create(:user) }
      let(:user_b) { create(:user) }

      let!(:version_a) do
        CurrentUser.scoped(user_a, "127.0.0.1") { create(:post_version) }
      end

      let!(:version_b) do
        CurrentUser.scoped(user_b, "127.0.0.1") { create(:post_version) }
      end

      it "returns versions whose updater_id matches the given user" do
        expect(PostVersion.for_user(user_a.id)).to include(version_a)
      end

      it "excludes versions from other users" do
        expect(PostVersion.for_user(user_a.id)).not_to include(version_b)
      end

      it "returns none when user_id is nil" do
        expect(PostVersion.for_user(nil)).to eq(PostVersion.none)
      end
    end
  end
end
