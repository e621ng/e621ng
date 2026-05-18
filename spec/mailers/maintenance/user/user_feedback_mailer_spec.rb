# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::UserFeedbackMailer do
  include_context "as admin"

  describe "#feedback_notice" do
    let(:user)     { create(:user) }
    let(:feedback) { create(:user_feedback, user: user) }

    it "returns a mail with correct to and subject" do
      mail = described_class.feedback_notice(user, feedback)
      expect(mail.to).to include(user.email)
      expect(mail.subject).to include("Account Record")
    end

    it "builds no recipient when user has no email" do
      allow(user).to receive(:email).and_return("")
      expect(described_class.feedback_notice(user, feedback).to).to be_nil
    end
  end
end
