# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                              User::EmailMethods                             #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  describe "email methods" do
    let(:user) { create(:user) }

    # -------------------------------------------------------------------------
    # .generate_email_verification_key
    # -------------------------------------------------------------------------
    describe ".generate_email_verification_key" do
      it "returns a 32-character hex string" do
        expect(User.generate_email_verification_key).to match(/\A\h{32}\z/)
      end

      it "returns a different value each call" do
        expect(User.generate_email_verification_key).not_to eq(User.generate_email_verification_key)
      end
    end

    # -------------------------------------------------------------------------
    # #mark_unverified! / #mark_verified!
    # -------------------------------------------------------------------------
    describe "#mark_unverified!" do
      it "marks a verified user as unverified" do
        expect { user.mark_unverified! }.to change { user.reload.is_verified? }.from(true).to(false)
      end

      it "rotates the key on every call" do
        user.mark_unverified!
        first_key = user.reload.email_verification_key
        user.mark_unverified!
        expect(user.reload.email_verification_key).not_to eq(first_key)
      end
    end

    describe "#mark_verified!" do
      it "clears the key" do
        user.mark_unverified!
        user.mark_verified!
        expect(user.reload.email_verification_key).to be_nil
      end
    end

    # -------------------------------------------------------------------------
    # #email_verification_key_matches?
    # -------------------------------------------------------------------------
    describe "#email_verification_key_matches?" do
      before { user.mark_unverified! }

      it "is true for the current key" do
        expect(user.email_verification_key_matches?(user.email_verification_key)).to be(true)
      end

      it "is false for a different key" do
        expect(user.email_verification_key_matches?(User.generate_email_verification_key)).to be(false)
      end

      it "is false for blank or non-string keys" do
        expect(user.email_verification_key_matches?(nil)).to be(false)
        expect(user.email_verification_key_matches?("")).to be(false)
        expect(user.email_verification_key_matches?(123)).to be(false)
      end

      it "is false when the user is verified" do
        user.mark_verified!
        expect(user.email_verification_key_matches?("")).to be(false)
        expect(user.email_verification_key_matches?(nil)).to be(false)
      end
    end
  end
end
