# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        SearchTrend Validations                              #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrend do
  # -------------------------------------------------------------------------
  # tag — presence
  # -------------------------------------------------------------------------
  describe "tag — presence" do
    it "is invalid when tag is blank" do
      record = build(:search_trend, tag: "")
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # tag — tag_name format (on: :create only)
  # -------------------------------------------------------------------------
  describe "tag — tag_name format" do
    it "is invalid on create with a tag containing illegal characters" do
      record = build(:search_trend, tag: "invalid*tag")
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to be_present
    end

    it "skips the tag_name validator on update" do
      record = create(:search_trend, tag: "valid_tag")
      record.update_columns(tag: "invalid!tag")
      record.reload
      record.count = 5
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # tag — length
  # -------------------------------------------------------------------------
  describe "tag — length" do
    it "is invalid when tag exceeds 100 characters" do
      record = build(:search_trend, tag: "a" * 101)
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to be_present
    end

    it "is valid when tag is exactly 100 characters" do
      record = build(:search_trend, tag: "a" * 100)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # day — presence
  # -------------------------------------------------------------------------
  describe "day — presence" do
    it "is invalid without day" do
      record = build(:search_trend, day: nil)
      expect(record).not_to be_valid
      expect(record.errors[:day]).to be_present
    end
  end
end
