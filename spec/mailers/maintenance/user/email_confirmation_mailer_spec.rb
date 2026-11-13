# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::EmailConfirmationMailer do
  include_context "as admin"

  describe "#confirmation" do
    let(:user) { create(:unverified_user) }

    it "returns a mail with correct to and subject" do
      mail = described_class.confirmation(user)
      expect(mail.to).to include(user.email)
      expect(mail.subject).to include("Account Confirmation")
    end

    it "links with a sig bound to the current verification key" do
      body = described_class.confirmation(user).body.decoded
      sig = CGI.unescape(body[/activate_user\?sig=([^"&]+)/, 1])
      expect(EmailLinkValidator.validate(sig, :activate)).to eq([user.id, user.email_verification_key])
    end

    it "builds no recipient when the user is already verified" do
      user.mark_verified!
      expect(described_class.confirmation(user).to).to be_nil
    end

    it "builds no recipient when user has no email" do
      allow(user).to receive(:email).and_return("")
      expect(described_class.confirmation(user).to).to be_nil
    end

    it "does not raise and delivers nothing for a malformed legacy email" do
      allow(user).to receive(:email).and_return("Email- Something-Weird-Comes@hotmail.com")
      ActionMailer::Base.deliveries.clear
      expect { described_class.confirmation(user).deliver_now }.not_to raise_error
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
