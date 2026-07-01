# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersion do
  include_context "as admin"

  describe "factory" do
    it "produces a valid record with build" do
      pv = build(:post_version)
      expect(pv).to be_valid, pv.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      expect(create(:post_version)).to be_persisted
    end

    it "sets the updater association via belongs_to_updater" do
      pv = create(:post_version)
      expect(pv.updater).to be_a(User)
    end

    it "sets version to a positive integer" do
      pv = create(:post_version)
      expect(pv.version).to be >= 1
    end

    it "populates added_tags on the first version" do
      pv = create(:post, tag_string: "foo bar").versions.first
      expect(pv.added_tags).to match_array(%w[foo bar])
    end

    it "has empty removed_tags on the first version" do
      pv = create(:post, tag_string: "foo bar").versions.first
      expect(pv.removed_tags).to be_empty
    end
  end
end
