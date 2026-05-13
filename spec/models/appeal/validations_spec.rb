# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  include_context "as member"

  def make_appeal(overrides = {})
    create(:appeal, **overrides)
  end

  def build_appeal(overrides = {})
    build(:appeal, **overrides)
  end

  # -------------------------------------------------------------------------
  # qtype
  # -------------------------------------------------------------------------
  describe "qtype validation" do
    it "is invalid without a qtype" do
      record = build_appeal
      record.qtype = nil
      expect(record).not_to be_valid
      expect(record.errors[:qtype]).to be_present
    end

    it "is invalid with an unknown qtype" do
      record = build(:appeal, qtype: "invalid_type")
      expect(record).not_to be_valid
      expect(record.errors[:qtype]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # reason
  # -------------------------------------------------------------------------
  describe "reason validation" do
    it "is invalid without a reason" do
      record = build_appeal
      record.reason = nil
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is invalid with a reason shorter than 2 characters" do
      record = build_appeal(reason: "x")
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is valid with a reason of exactly 2 characters" do
      expect(build_appeal(reason: "ab")).to be_valid
    end

    it "is invalid with a reason exceeding ticket_max_size characters" do
      record = build_appeal(reason: "a" * (Danbooru.config.ticket_max_size + 1))
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is valid with a reason of exactly ticket_max_size characters" do
      expect(build_appeal(reason: "a" * Danbooru.config.ticket_max_size)).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # response (update only)
  # -------------------------------------------------------------------------
  describe "response validation" do
    it "does not require a response on create" do
      record = build_appeal
      record.response = nil
      expect(record).to be_valid
    end

    it "is invalid on update when response is 1 character" do
      appeal = make_appeal
      appeal.response = "x"
      expect(appeal).not_to be_valid
      expect(appeal.errors[:response]).to be_present
    end

    it "is valid on update when response is at least 2 characters" do
      appeal = make_appeal
      appeal.response = "ok"
      expect(appeal).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # validate_content_exists (on create)
  # -------------------------------------------------------------------------
  describe "content existence validation" do
    it "is valid when the referenced PostFlag exists" do
      expect(build_appeal).to be_valid
    end

    it "is invalid when the referenced PostFlag does not exist" do
      record = build(:appeal, post_flag: build(:post_flag))
      expect(record).not_to be_valid
      expect(record.errors[:post_flag]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # validate_creator_is_not_limited (on create)
  # -------------------------------------------------------------------------
  describe "creator throttle validation" do
    it "is invalid when the hourly appeal limit is exceeded" do
      allow(Danbooru.config.custom_configuration).to receive(:ticket_hourly_limit).and_return(1)
      make_appeal
      record = build(:appeal, post_flag: create(:post_flag))
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "is invalid when the daily appeal limit is exceeded" do
      allow(Danbooru.config.custom_configuration).to receive(:ticket_daily_limit).and_return(1)
      make_appeal
      record = build(:appeal, post_flag: create(:post_flag))
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "is invalid when the active appeal limit is exceeded" do
      allow(Danbooru.config.custom_configuration).to receive(:ticket_active_limit).and_return(1)
      make_appeal
      record = build(:appeal, post_flag: create(:post_flag))
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "allows the system user to bypass throttle limits" do
      allow(Danbooru.config.custom_configuration).to receive(:ticket_hourly_limit).and_return(0)
      CurrentUser.user = User.system
      record = build(:appeal, post_flag: create(:post_flag))
      expect(record).to be_valid
    end
  end
end
