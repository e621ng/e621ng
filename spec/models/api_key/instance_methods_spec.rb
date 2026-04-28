# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ApiKey Instance Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe ApiKey do
  include_context "as member"

  def make_api_key(overrides = {})
    create(:api_key, user: CurrentUser.user, **overrides)
  end

  # -------------------------------------------------------------------------
  # .generate! (class method)
  # -------------------------------------------------------------------------
  describe ".generate!" do
    it "creates and persists a key for the given user with the given name" do
      key = ApiKey.generate!(CurrentUser.user, name: "My Key")
      expect(key).to be_persisted
      expect(key.user_id).to eq(CurrentUser.user.id)
      expect(key.name).to eq("My Key")
    end

    it "creates a key with a future expires_at when provided" do
      expiry = 30.days.from_now
      key = ApiKey.generate!(CurrentUser.user, name: "Expiring", expires_at: expiry)
      expect(key.expires_at).to be_within(1.second).of(expiry)
    end

    it "creates a key with nil expires_at when expires_at is not given" do
      key = ApiKey.generate!(CurrentUser.user, name: "Permanent")
      expect(key.expires_at).to be_nil
    end

    it "raises ActiveRecord::RecordInvalid when the name is blank" do
      expect do
        ApiKey.generate!(CurrentUser.user, name: "")
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # -------------------------------------------------------------------------
  # #expired?
  # -------------------------------------------------------------------------
  describe "#expired?" do
    it "returns false when expires_at is nil" do
      key = make_api_key
      expect(key.expired?).to be false
    end

    it "returns false when expires_at is in the future" do
      key = make_api_key(expires_at: 1.day.from_now)
      expect(key.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      key = make_api_key
      key.update_columns(expires_at: 1.second.ago)
      expect(key.expired?).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #active?
  # -------------------------------------------------------------------------
  describe "#active?" do
    it "returns true when the key is not expired" do
      key = make_api_key
      expect(key.active?).to be true
    end

    it "returns false when the key is expired" do
      key = make_api_key
      key.update_columns(expires_at: 1.second.ago)
      expect(key.active?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #update_usage!
  # -------------------------------------------------------------------------
  describe "#update_usage!" do
    subject(:key) { make_api_key }

    it "sets last_used_at to approximately now" do
      key.update_usage!
      expect(key.reload.last_used_at).to be_within(2.seconds).of(Time.current)
    end

    it "records the provided ip_address in last_ip_address" do
      key.update_usage!("192.168.1.1")
      expect(key.reload.last_ip_address.to_s).to eq("192.168.1.1")
    end

    it "records the provided user_agent string in last_user_agent" do
      key.update_usage!(nil, "Mozilla/5.0")
      expect(key.reload.last_user_agent).to eq("Mozilla/5.0")
    end

    it "sets last_used_at even when ip_address and user_agent are nil" do
      key.update_usage!
      expect(key.reload.last_used_at).to be_present
      expect(key.reload.last_ip_address).to be_nil
      expect(key.reload.last_user_agent).to be_nil
    end

    it "persists all three fields in the database" do
      key.update_usage!("10.0.0.1", "TestAgent/1.0")
      key.reload
      expect(key.last_used_at).to be_present
      expect(key.last_ip_address.to_s).to eq("10.0.0.1")
      expect(key.last_user_agent).to eq("TestAgent/1.0")
    end
  end

  # -------------------------------------------------------------------------
  # #visible?
  # -------------------------------------------------------------------------
  describe "#visible?" do
    subject(:key)    { make_api_key }

    let(:other_user) { create(:user) }

    it "returns true when the given user is the owner" do
      expect(key.visible?(CurrentUser.user)).to be true
    end

    it "returns false when the given user is a different user" do
      expect(key.visible?(other_user)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #regenerate!
  # -------------------------------------------------------------------------
  describe "#regenerate!" do
    it "generates a new key token, replacing the old one" do
      key = make_api_key
      old_token = key.key
      key.regenerate!
      expect(key.reload.key).not_to eq(old_token)
    end

    it "resets notified_at to nil" do
      key = make_api_key(expires_at: 30.days.from_now)
      key.update_columns(notified_at: 1.day.ago)
      key.regenerate!
      expect(key.reload.notified_at).to be_nil
    end

    it "preserves the original duration when the key had an expiry" do
      key = make_api_key(expires_at: 30.days.from_now)
      key.regenerate!
      expect(key.reload.expires_at).to be_within(5.seconds).of(30.days.from_now)
    end

    it "sets expires_at to nil when the original key had no expiry" do
      key = make_api_key
      key.regenerate!
      expect(key.reload.expires_at).to be_nil
    end

    it "updates created_at to approximately now" do
      key = make_api_key
      key.update_columns(created_at: 1.hour.ago)
      key.regenerate!
      expect(key.reload.created_at).to be_within(2.seconds).of(Time.current)
    end

    it "persists all changes to the database" do
      key = make_api_key(expires_at: 14.days.from_now)
      key.update_columns(notified_at: 1.day.ago)
      old_token = key.key
      key.regenerate!
      key.reload
      expect(key.key).not_to eq(old_token)
      expect(key.notified_at).to be_nil
      expect(key.expires_at).to be_within(5.seconds).of(14.days.from_now)
    end
  end
end
