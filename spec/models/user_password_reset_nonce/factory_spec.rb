# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     UserPasswordResetNonce Factory                          #
# --------------------------------------------------------------------------- #

RSpec.describe UserPasswordResetNonce do
  include_context "as member"

  describe "factory" do
    it "produces a valid nonce with build" do
      nonce = build(:user_password_reset_nonce)
      expect(nonce).to be_valid, nonce.errors.full_messages.join(", ")
    end

    it "produces a valid nonce with create" do
      nonce = create(:user_password_reset_nonce)
      expect(nonce).to be_persisted
    end
  end
end
