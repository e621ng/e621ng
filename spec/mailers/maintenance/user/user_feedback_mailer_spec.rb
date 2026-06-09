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

    it "does not raise and delivers nothing for a malformed legacy email" do
      allow(user).to receive(:email).and_return("Email- Something-Weird-Comes@hotmail.com")
      ActionMailer::Base.deliveries.clear
      expect { described_class.feedback_notice(user, feedback).deliver_now }.not_to raise_error
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
