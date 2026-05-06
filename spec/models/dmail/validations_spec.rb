# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            Dmail Validations                                #
# --------------------------------------------------------------------------- #

RSpec.describe Dmail do
  # ---------------------------------------------------------------------------
  # Shared setup: a sender as the current user, bypass_limits avoids noise from
  # rate-limit checks in tests that focus on other validations.
  # ---------------------------------------------------------------------------
  let(:sender)    { create(:user) }
  let(:recipient) { create(:user) }

  before do
    CurrentUser.user    = sender
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  def make(overrides = {})
    build(:dmail, from: sender, to: recipient, **overrides)
  end

  # ---------------------------------------------------------------------------
  # title
  # ---------------------------------------------------------------------------
  describe "title" do
    describe "presence (on create)" do
      it "is invalid without a title" do
        record = make(title: nil)
        expect(record).not_to be_valid
        expect(record.errors[:title]).to be_present
      end

      it "is invalid with a blank title" do
        record = make(title: "")
        expect(record).not_to be_valid
        expect(record.errors[:title]).to be_present
      end
    end

    describe "length" do
      it "is valid at exactly 250 characters" do
        expect(make(title: "a" * 250)).to be_valid
      end

      it "is invalid when title exceeds 250 characters" do
        record = make(title: "a" * 251)
        expect(record).not_to be_valid
        expect(record.errors[:title]).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # body
  # ---------------------------------------------------------------------------
  describe "body" do
    describe "presence (on create)" do
      it "is invalid without a body" do
        record = make(body: nil)
        expect(record).not_to be_valid
        expect(record.errors[:body]).to be_present
      end

      it "is invalid with a blank body" do
        record = make(body: "")
        expect(record).not_to be_valid
        expect(record.errors[:body]).to be_present
      end
    end

    describe "length" do
      it "is valid at exactly dmail_max_size characters" do
        expect(make(body: "a" * Danbooru.config.dmail_max_size)).to be_valid
      end

      it "is invalid when body exceeds dmail_max_size" do
        record = make(body: "a" * (Danbooru.config.dmail_max_size + 1))
        expect(record).not_to be_valid
        expect(record.errors[:body]).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # recipient_accepts_dmails (on: :create)
  # ---------------------------------------------------------------------------
  describe "recipient_accepts_dmails" do
    it "is invalid when to_id does not reference an existing user" do
      record = make
      record.to_id = -1
      expect(record).not_to be_valid
      expect(record.errors[:to_name]).to be_present
    end

    it "is invalid when the recipient has disabled dmails" do
      recipient.update_columns(bit_prefs: recipient.bit_prefs | User.flag_value_for("disable_user_dmails"))
      record = make
      expect(record).not_to be_valid
      expect(record.errors[:to_name]).to include("has disabled DMails")
    end

    it "is invalid when the sender has disabled dmails and the recipient is not a janitor" do
      sender.update_columns(bit_prefs: sender.bit_prefs | User.flag_value_for("disable_user_dmails"))
      record = make
      expect(record).not_to be_valid
      expect(record.errors[:to_name]).to be_present
    end

    it "is valid when the sender has disabled dmails but the recipient is a janitor" do
      sender.update_columns(bit_prefs: sender.bit_prefs | User.flag_value_for("disable_user_dmails"))
      janitor = create(:janitor_user)
      record  = make(to: janitor)
      expect(record).to be_valid
    end

    it "is invalid when the recipient has the sender on their blacklist" do
      recipient.update_columns(blacklisted_tags: "user:#{sender.name}")
      record = make
      expect(record).not_to be_valid
      expect(record.errors[:to_name]).to include("does not wish to receive DMails from you")
    end

    it "is valid when from is the system user (bypasses all recipient checks)" do
      recipient.update_columns(bit_prefs: recipient.bit_prefs | User.flag_value_for("disable_user_dmails"))
      record = build(:dmail, from: User.system, to: recipient, owner: recipient, bypass_limits: true, no_email_notification: true)
      CurrentUser.as_system { expect(record).to be_valid }
    end

    it "is valid when from is a janitor (bypasses all recipient checks)" do
      janitor = create(:janitor_user)
      recipient.update_columns(bit_prefs: recipient.bit_prefs | User.flag_value_for("disable_user_dmails"))
      record = make(from: janitor)
      CurrentUser.user = janitor
      expect(record).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # user_not_limited (on: :create)
  # ---------------------------------------------------------------------------
  describe "user_not_limited" do
    it "bypasses all rate-limit checks when bypass_limits is true" do
      record = make(bypass_limits: true)
      # Confirm no rate-limit errors even though CurrentUser is a regular member
      record.valid?
      expect(record.errors[:base].grep_v(/Sender|Please wait/)).to eq(record.errors[:base].to_a)
    end

    it "bypasses when from is the system user" do
      record = build(:dmail, from: User.system, to: recipient, owner: recipient,
                             bypass_limits: false, no_email_notification: true)
      CurrentUser.as_system { record.valid? }
      expect(record.errors[:base]).to be_empty
    end

    it "bypasses when from is a janitor" do
      janitor = create(:janitor_user)
      CurrentUser.user = janitor
      record = build(:dmail, from: janitor, to: recipient, owner: recipient,
                             bypass_limits: false, no_email_notification: true)
      record.valid?
      expect(record.errors[:base]).to be_empty
    end

    it "adds an error when the daily dmail limit is exceeded" do
      CurrentUser.user = sender
      record = make(bypass_limits: false)
      allow(sender).to receive(:can_dmail_with_reason).and_return(:account_too_new)
      record.valid?
      expect(record.errors[:base]).to be_present
    end

    it "adds a per-minute throttle error when sending too fast" do
      CurrentUser.user = sender
      record = make(bypass_limits: false)
      allow(sender).to receive_messages(
        can_dmail_with_reason: true,
        can_dmail_minute_with_reason: :too_fast,
      )
      record.valid?
      expect(record.errors[:base]).to include("Please wait a bit before trying to send again")
    end

    it "adds a daily throttle error when the day limit is exceeded" do
      CurrentUser.user = sender
      record = make(bypass_limits: false)
      allow(sender).to receive_messages(
        can_dmail_with_reason: true,
        can_dmail_minute_with_reason: true,
        can_dmail_day_with_reason: :too_many_today,
      )
      record.valid?
      expect(record.errors[:base]).to be_present
    end
  end
end
