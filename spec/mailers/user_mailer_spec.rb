# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMailer do
  include_context "as admin"

  describe "#dmail_notice" do
    let(:dmail) { create(:dmail, no_email_notification: false) }

    it "returns a mail with correct to and subject" do
      mail = UserMailer.dmail_notice(dmail)
      expect(mail.to).to include(dmail.to.email)
      expect(mail.subject).to include(dmail.from.name)
    end

    it "builds no recipient when recipient has no email" do
      allow(dmail.to).to receive(:email).and_return("")
      expect(UserMailer.dmail_notice(dmail).to).to be_nil
    end
  end

  describe "#forum_notice" do
    let(:user)        { create(:user) }
    let(:forum_topic) { create(:forum_topic) }

    it "returns a mail with correct to and subject" do
      mail = UserMailer.forum_notice(user, forum_topic, [])
      expect(mail.to).to include(user.email)
      expect(mail.subject).to include(forum_topic.title)
    end

    it "builds no recipient when user has no email" do
      allow(user).to receive(:email).and_return("")
      expect(UserMailer.forum_notice(user, forum_topic, []).to).to be_nil
    end
  end
end
