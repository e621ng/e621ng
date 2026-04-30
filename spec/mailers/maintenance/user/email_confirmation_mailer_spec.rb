# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::EmailConfirmationMailer do
  include_context "as admin"

  describe "#confirmation" do
    let(:user) { create(:user) }

    it "returns a mail with correct to and subject" do
      mail = described_class.confirmation(user)
      expect(mail.to).to include(user.email)
      expect(mail.subject).to include("Account Confirmation")
    end

    it "builds no recipient when user has no email" do
      allow(user).to receive(:email).and_return("")
      expect(described_class.confirmation(user).to).to be_nil
    end
  end
end
