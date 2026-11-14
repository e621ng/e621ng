# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            User::PasswordMethods                            #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  include_context "as member"

  describe "password methods" do
    let(:user) { create(:user) }

    describe "#invalidate_password_reset_nonces" do
      it "deletes only that user's nonces" do
        mine = create(:user_password_reset_nonce, user: user)
        other = create(:user_password_reset_nonce)
        user.invalidate_password_reset_nonces
        expect(UserPasswordResetNonce.where(id: mine.id)).not_to exist
        expect(UserPasswordResetNonce.where(id: other.id)).to exist
      end
    end

    describe "nonce invalidation on update" do
      let!(:nonce) { create(:user_password_reset_nonce, user: user) }

      it "fires when the password is changed" do
        expect(user.update(old_password: "hexerade", password: "hexerade1234", password_confirmation: "hexerade1234")).to be true
        expect(UserPasswordResetNonce.where(id: nonce.id)).not_to exist
      end

      it "fires when the email is changed" do
        expect(user.update(email: "changed@example.com")).to be true
        expect(UserPasswordResetNonce.where(id: nonce.id)).not_to exist
      end

      it "does not fire on an unrelated update" do
        expect(user.update(comment_threshold: 5)).to be true
        expect(UserPasswordResetNonce.where(id: nonce.id)).to exist
      end

      it "does not fire through upgrade_password alone" do
        user.upgrade_password("hexerade1234")
        expect(UserPasswordResetNonce.where(id: nonce.id)).to exist
      end
    end
  end
end
