# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   UserPasswordResetNonce Validations                        #
# --------------------------------------------------------------------------- #

RSpec.describe UserPasswordResetNonce do
  include_context "as member"

  def make_nonce(overrides = {})
    build(:user_password_reset_nonce, **overrides)
  end

  # -------------------------------------------------------------------------
  # belongs_to :user
  # -------------------------------------------------------------------------
  describe "user presence" do
    it "is invalid without a user" do
      nonce = make_nonce(user: nil)
      expect(nonce).not_to be_valid
      expect(nonce.errors[:user]).to be_present
    end

    it "is valid with a user" do
      expect(make_nonce).to be_valid
    end
  end
end
