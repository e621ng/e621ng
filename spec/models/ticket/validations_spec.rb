# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket do
  include_context "as member"

  def make_ticket(overrides = {})
    create(:ticket, **overrides)
  end

  def build_ticket(overrides = {})
    build(:ticket, **overrides)
  end

  # -------------------------------------------------------------------------
  # qtype
  # -------------------------------------------------------------------------
  describe "qtype validation" do
    it "is invalid without a qtype" do
      record = build_ticket
      record.qtype = nil
      expect(record).not_to be_valid
      expect(record.errors[:qtype]).to be_present
    end

    it "is invalid with an unknown qtype" do
      record = build(:ticket, qtype: "invalid_type")
      expect(record).not_to be_valid
      expect(record.errors[:qtype]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # reason
  # -------------------------------------------------------------------------
  describe "reason validation" do
    it "is invalid without a reason" do
      record = build_ticket
      record.reason = nil
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is invalid with a reason shorter than 2 characters" do
      record = build_ticket(reason: "x")
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is valid with a reason of exactly 2 characters" do
      record = build_ticket(reason: "ab")
      expect(record).to be_valid
    end

    it "is invalid with a reason exceeding ticket_max_size characters" do
      record = build_ticket(reason: "a" * (Danbooru.config.ticket_max_size + 1))
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is valid with a reason of exactly ticket_max_size characters" do
      record = build_ticket(reason: "a" * Danbooru.config.ticket_max_size)
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # response (update only)
  # -------------------------------------------------------------------------
  describe "response validation" do
    it "does not require response on create" do
      record = build_ticket
      record.response = nil
      expect(record).to be_valid
    end

    it "is invalid on update when response is 1 character" do
      ticket = make_ticket
      ticket.response = "x"
      expect(ticket).not_to be_valid
      expect(ticket.errors[:response]).to be_present
    end

    it "is valid on update when response is at least 2 characters" do
      ticket = make_ticket
      ticket.response = "ok"
      expect(ticket).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # validate_content_exists (on create)
  # -------------------------------------------------------------------------
  describe "content existence validation" do
    it "is invalid when content does not exist" do
      record = build(:ticket, :pool_type)
      record.disp_id = 0
      expect(record).not_to be_valid
      expect(record.errors[:pool]).to be_present
    end

    it "is valid when content exists" do
      expect(build(:ticket, :pool_type)).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # validate_creator_is_not_limited (on create)
  # -------------------------------------------------------------------------
  describe "creator throttle validation" do
    it "is invalid when the hourly ticket limit is exceeded" do
      allow(Danbooru.config.custom_configuration).to receive(:ticket_hourly_limit).and_return(1)
      make_ticket
      record = build_ticket(accused_user: create(:user))
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "is invalid when the daily ticket limit is exceeded" do
      allow(Danbooru.config.custom_configuration).to receive(:ticket_daily_limit).and_return(1)
      make_ticket
      record = build_ticket(accused_user: create(:user))
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "is invalid when the active ticket limit is exceeded" do
      allow(Danbooru.config.custom_configuration).to receive(:ticket_active_limit).and_return(1)
      make_ticket
      record = build_ticket(accused_user: create(:user))
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "allows the system user to bypass throttle limits" do
      allow(Danbooru.config.custom_configuration).to receive(:ticket_hourly_limit).and_return(0)
      CurrentUser.user = User.system
      record = build_ticket(accused_user: create(:user))
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # post type — report_reason required
  # -------------------------------------------------------------------------
  describe "report_reason validation for post type" do
    it "is invalid without a report_reason" do
      record = build(:ticket, :post_type)
      record.report_reason = nil
      expect(record).not_to be_valid
      expect(record.errors[:report_reason]).to be_present
    end

    it "is valid with a report_reason present" do
      expect(build(:ticket, :post_type)).to be_valid
    end
  end
end
