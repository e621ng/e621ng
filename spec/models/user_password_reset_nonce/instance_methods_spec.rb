# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                 UserPasswordResetNonce Instance Methods                     #
# --------------------------------------------------------------------------- #

RSpec.describe UserPasswordResetNonce do
  include_context "as member"

  def make_nonce(overrides = {})
    create(:user_password_reset_nonce, **overrides)
  end

  # -------------------------------------------------------------------------
  # #expired?
  # -------------------------------------------------------------------------
  describe "#expired?" do
    it "returns false for a freshly created nonce" do
      nonce = make_nonce
      expect(nonce.expired?).to be false
    end

    it "returns false when the nonce is just under 6 hours old" do
      nonce = make_nonce
      nonce.update_columns(created_at: 6.hours.ago + 1.second)
      expect(nonce.expired?).to be false
    end

    it "returns true when the nonce is older than 6 hours" do
      nonce = make_nonce
      nonce.update_columns(created_at: 7.hours.ago)
      expect(nonce.expired?).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #reset_user!
  # -------------------------------------------------------------------------
  describe "#reset_user!" do
    it "returns false when the passwords do not match" do
      nonce = make_nonce
      expect(nonce.reset_user!("password123", "different456")).to be false
    end

    it "returns true when the passwords match" do
      nonce = make_nonce
      expect(nonce.reset_user!("password123", "password123")).to be true
    end

    it "calls upgrade_password on the user when passwords match" do
      nonce = make_nonce
      allow(nonce.user).to receive(:upgrade_password)
      nonce.reset_user!("newpassword", "newpassword")
      expect(nonce.user).to have_received(:upgrade_password).with("newpassword")
    end

    it "does not call upgrade_password when passwords do not match" do
      nonce = make_nonce
      allow(nonce.user).to receive(:upgrade_password)
      nonce.reset_user!("password123", "different456")
      expect(nonce.user).not_to have_received(:upgrade_password)
    end
  end

  # -------------------------------------------------------------------------
  # #deliver_notice (tested via after_create callback)
  # -------------------------------------------------------------------------
  describe "#deliver_notice" do
    before { ActionMailer::Base.deliveries.clear }

    it "sends a password reset email when the user has an email address" do
      user = create(:user)
      expect { create(:user_password_reset_nonce, user: user) }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "does not send an email when the user has no email address" do
      user = create(:user)
      allow(user).to receive(:email).and_return("")
      nonce = build(:user_password_reset_nonce, user: user)
      expect { nonce.save! }.not_to(change { ActionMailer::Base.deliveries.count })
    end
  end
end
