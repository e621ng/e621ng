# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     SearchTrendHourly Validations                           #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendHourly do
  # -------------------------------------------------------------------------
  # tag — presence
  # -------------------------------------------------------------------------
  describe "tag — presence" do
    it "is invalid when tag is blank" do
      record = build(:search_trend_hourly, tag: "")
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # tag — tag_name format (on: :create only)
  # -------------------------------------------------------------------------
  describe "tag — tag_name format" do
    it "is invalid on create with a tag containing illegal characters" do
      record = build(:search_trend_hourly, tag: "invalid*tag")
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to be_present
    end

    it "skips the tag_name validator on update" do
      record = create(:search_trend_hourly, tag: "valid_tag")
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
      record = build(:search_trend_hourly, tag: "a" * 101)
      expect(record).not_to be_valid
      expect(record.errors[:tag]).to be_present
    end

    it "is valid when tag is exactly 100 characters" do
      record = build(:search_trend_hourly, tag: "a" * 100)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # hour — presence
  # -------------------------------------------------------------------------
  describe "hour — presence" do
    it "is invalid without hour" do
      record = build(:search_trend_hourly, hour: nil)
      expect(record).not_to be_valid
      expect(record.errors[:hour]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # count — presence
  # -------------------------------------------------------------------------
  describe "count — presence" do
    it "is invalid without count" do
      record = build(:search_trend_hourly, count: nil)
      expect(record).not_to be_valid
      expect(record.errors[:count]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # count — numericality
  # -------------------------------------------------------------------------
  describe "count — numericality" do
    it "is invalid with a negative count" do
      record = build(:search_trend_hourly, count: -1)
      expect(record).not_to be_valid
      expect(record.errors[:count]).to be_present
    end

    it "is invalid with a non-integer count" do
      record = build(:search_trend_hourly, count: 1.5)
      expect(record).not_to be_valid
      expect(record.errors[:count]).to be_present
    end

    it "is valid with count = 0" do
      record = build(:search_trend_hourly, count: 0)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # uniqueness of [tag, hour]
  # -------------------------------------------------------------------------
  describe "uniqueness of [tag, hour]" do
    let(:fixed_hour) { Time.utc(2026, 1, 1, 6, 0, 0) }

    it "is invalid when a record with the same tag and hour already exists" do
      create(:search_trend_hourly, tag: "unique_tag", hour: fixed_hour)
      duplicate = build(:search_trend_hourly, tag: "unique_tag", hour: fixed_hour)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:hour]).to be_present
    end

    it "is valid for the same tag at a different hour" do
      create(:search_trend_hourly, tag: "same_tag", hour: fixed_hour)
      record = build(:search_trend_hourly, tag: "same_tag", hour: fixed_hour + 1.hour)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it "is valid for a different tag at the same hour" do
      create(:search_trend_hourly, tag: "tag_a", hour: fixed_hour)
      record = build(:search_trend_hourly, tag: "tag_b", hour: fixed_hour)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end
  end
end
