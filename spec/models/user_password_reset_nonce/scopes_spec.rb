# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   UserPasswordResetNonce Class Methods                      #
# --------------------------------------------------------------------------- #

RSpec.describe UserPasswordResetNonce do
  include_context "as member"

  before { ActionMailer::Base.deliveries.clear }

  # -------------------------------------------------------------------------
  # .prune!
  # -------------------------------------------------------------------------
  describe ".prune!" do
    it "destroys nonces older than 2 days" do
      old_nonce = create(:user_password_reset_nonce)
      old_nonce.update_columns(created_at: 3.days.ago)
      expect { UserPasswordResetNonce.prune! }.to change(UserPasswordResetNonce, :count).by(-1)
    end

    it "does not destroy nonces created within the last 2 days" do
      create(:user_password_reset_nonce)
      expect { UserPasswordResetNonce.prune! }.not_to change(UserPasswordResetNonce, :count)
    end

    it "removes only old nonces when both old and recent records exist" do
      recent = create(:user_password_reset_nonce)
      old    = create(:user_password_reset_nonce)
      old.update_columns(created_at: 3.days.ago)

      expect { UserPasswordResetNonce.prune! }.to change(UserPasswordResetNonce, :count).by(-1)
      expect(UserPasswordResetNonce.exists?(recent.id)).to be true
      expect(UserPasswordResetNonce.exists?(old.id)).to be false
    end
  end
end
