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

    describe "changing the password" do
      it "reports a wrong old password and keeps the existing one" do
        user.update(old_password: "not_the_password", password: "hexerade1234", password_confirmation: "hexerade1234")
        expect(user.errors[:old_password]).to include("is incorrect")
        expect(User.authenticate(user.name, "hexerade1234")).to be_nil
        expect(User.authenticate(user.name, "hexerade")).to eq(user)
      end

      it "does not revoke sessions or reset nonces for a wrong old password" do
        session = create(:user_session, user: user)
        nonce = create(:user_password_reset_nonce, user: user)
        user.update(old_password: "not_the_password", password: "hexerade1234", password_confirmation: "hexerade1234")
        expect(session.reload.revoked_at).to be_nil
        expect(UserPasswordResetNonce.where(id: nonce.id)).to exist
      end

      it "is rejected when the new password is too long to analyse" do
        long = "aB3$#{SecureRandom.alphanumeric(300)}"
        expect(user.update(old_password: "hexerade", password: long, password_confirmation: long)).to be false
        expect(user.errors[:password]).to include("is too long")
      end

      it "is rejected when the new password is weak and the analyser gives no warning" do
        user # create before the analyser is replaced
        feedback = instance_double(Zxcvbn::Feedback, warning: nil)
        analysis = instance_double(Zxcvbn::Score, score: 1, feedback: feedback)
        stub_const("ZXCVBN_TESTER", instance_double(Zxcvbn::Tester, test: analysis)) # the real tester is frozen
        expect(user.update(old_password: "hexerade", password: "hexerade1234", password_confirmation: "hexerade1234")).to be false
        expect(user.errors[:password]).to eq(["is insecure"])
      end
    end

    describe ".authenticate" do
      it "returns nil for a wrong password" do
        expect(User.authenticate(user.name, "not_the_password")).to be_nil
      end

      it "returns nil for an unknown user" do
        expect(User.authenticate("i_am_not_a_user", "hexerade")).to be_nil
      end

      context "with a legacy PBKDF2 hash" do
        before { user.update_columns(password_hash: Pbkdf2.create_hash("legacy_password"), bcrypt_password_hash: nil) }

        it "returns the user and upgrades the hash to bcrypt" do
          expect(User.authenticate(user.name, "legacy_password")).to eq(user)
          user.reload
          expect(user.password_hash).to eq("")
          expect(user.bcrypt_password).to eq("legacy_password")
        end

        it "revokes the user's sessions on upgrade" do
          session = create(:user_session, user: user)
          User.authenticate(user.name, "legacy_password")
          expect(session.reload.revoked_at).to be_present
        end

        it "returns nil and leaves the hash alone for a wrong password" do
          expect(User.authenticate(user.name, "not_the_password")).to be_nil
          expect(user.reload.password_hash).to be_present
        end
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
