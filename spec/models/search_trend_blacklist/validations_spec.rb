# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   SearchTrendBlacklist Validations                          #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendBlacklist do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # tag — presence
  # -------------------------------------------------------------------------
  describe "tag — presence" do
    it "is invalid when tag is blank" do
      record = build(:search_trend_blacklist, tag: "")
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # tag — uniqueness (case-insensitive)
  # -------------------------------------------------------------------------
  describe "tag — uniqueness" do
    it "is invalid when a blacklist entry with the same tag already exists" do
      create(:search_trend_blacklist, tag: "duplicate_tag")
      record = build(:search_trend_blacklist, tag: "duplicate_tag")
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to include("already exists")
    end

    it "is invalid when a blacklist entry with the same tag in a different case already exists" do
      create(:search_trend_blacklist, tag: "fox_tag")
      record = build(:search_trend_blacklist, tag: "FOX_TAG")
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to include("already exists")
    end
  end

  # -------------------------------------------------------------------------
  # tag — bare wildcard rejection
  # -------------------------------------------------------------------------
  describe "tag — bare wildcard" do
    it 'is invalid when tag is exactly "*"' do
      record = build(:search_trend_blacklist, tag: "*")
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to be_present
    end

    it 'is valid when tag is a non-bare glob like "fox_*"' do
      record = build(:search_trend_blacklist, tag: "fox_*")
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it 'is valid when tag is a ? glob like "fo?"' do
      record = build(:search_trend_blacklist, tag: "fo?")
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end
  end
end
