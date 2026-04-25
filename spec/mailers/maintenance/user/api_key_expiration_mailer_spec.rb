# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::ApiKeyExpirationMailer do
  include_context "as admin"

  describe "#expiration_notice" do
    let(:user)    { create(:user) }
    let(:api_key) { create(:api_key, user: user) }

    it "returns a mail with correct to and subject" do
      mail = described_class.expiration_notice(user, api_key)
      expect(mail.to).to include(user.email)
      expect(mail.subject).to include("API Key Expiration")
    end

    it "builds no recipient when user has no email" do
      allow(user).to receive(:email).and_return("")
      expect(described_class.expiration_notice(user, api_key).to).to be_nil
    end
  end
end
