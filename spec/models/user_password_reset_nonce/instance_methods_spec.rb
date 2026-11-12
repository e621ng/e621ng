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
    it "returns false with an error when the passwords do not match" do
      nonce = make_nonce
      expect(nonce.reset_user!("hexerade1234", "different456")).to be false
      expect(nonce.errors[:base].join).to include("doesn't match")
      expect(nonce.user.reload.bcrypt_password).to eq("hexerade")
    end

    it "returns false when both passwords are blank" do
      nonce = make_nonce
      expect(nonce.reset_user!("", "")).to be false
      expect(nonce.errors[:base].join).to include("can't be blank")
      expect(nonce.user.reload.bcrypt_password).to eq("hexerade")
    end

    it "returns false when the passwords are nil" do
      nonce = make_nonce
      expect(nonce.reset_user!(nil, nil)).to be false
      expect(nonce.user.reload.bcrypt_password).to eq("hexerade")
    end

    it "returns false when the password is too short" do
      nonce = make_nonce
      expect(nonce.reset_user!("short", "short")).to be false
      expect(nonce.errors[:base].join).to include("too short")
    end

    it "returns false when the password is insecure" do
      nonce = make_nonce
      expect(nonce.reset_user!("password", "password")).to be false
      expect(nonce.errors[:base].join).to include("insecure")
    end

    it "changes the password when the passwords match and are valid" do
      nonce = make_nonce
      expect(nonce.reset_user!("hexerade1234", "hexerade1234")).to be true
      user = nonce.user.reload
      expect(user.bcrypt_password).to eq("hexerade1234")
      expect(user.password_hash).to eq("")
    end

    it "deletes every nonce for the user but not other users' nonces" do
      nonce = make_nonce
      sibling = make_nonce(user: nonce.user)
      other = make_nonce
      nonce.reset_user!("hexerade1234", "hexerade1234")
      expect(UserPasswordResetNonce.where(id: [nonce.id, sibling.id])).not_to exist
      expect(UserPasswordResetNonce.where(id: other.id)).to exist
    end

    it "succeeds when the user fails an unrelated validation" do
      nonce = make_nonce
      nonce.user.update_columns(custom_title: "x" * 101)
      expect(nonce.reset_user!("hexerade1234", "hexerade1234")).to be true
      expect(nonce.user.reload.bcrypt_password).to eq("hexerade1234")
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
