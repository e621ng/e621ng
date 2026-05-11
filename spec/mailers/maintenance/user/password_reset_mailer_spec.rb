# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::PasswordResetMailer do
  include_context "as admin"

  describe "#reset_request" do
    let(:user)  { create(:user) }
    let(:nonce) { create(:user_password_reset_nonce, user: user) }

    it "returns a mail with correct to and subject" do
      mail = described_class.reset_request(user, nonce)
      expect(mail.to).to include(user.email)
      expect(mail.subject).to include("Password Reset")
    end

    it "builds no recipient when user has no email" do
      allow(user).to receive(:email).and_return("")
      expect(described_class.reset_request(user, nonce).to).to be_nil
    end
  end
end
