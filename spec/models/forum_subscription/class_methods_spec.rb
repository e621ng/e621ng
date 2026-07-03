# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForumSubscription do
  include_context "as admin"

  describe ".prune!" do
    it "deletes subscriptions with last_read_at older than 3 months" do
      old = create(:forum_subscription)
      old.update_columns(last_read_at: 4.months.ago)
      expect { described_class.prune! }.to change(described_class, :count).by(-1)
      expect(described_class.where(id: old.id)).to be_empty
    end

    it "keeps subscriptions with last_read_at within 3 months" do
      recent = create(:forum_subscription, last_read_at: 1.week.ago)
      expect { described_class.prune! }.not_to change(described_class, :count)
      expect(described_class.where(id: recent.id)).to exist
    end
  end

  describe ".process_all!" do
    let(:mail_message) { instance_spy(ActionMailer::MessageDelivery) }

    before { allow(UserMailer).to receive(:forum_notice).and_return(mail_message) }

    context "when the user is not verified" do
      it "does not send mail" do
        user = create(:user, email_verification_key: "pending")
        topic = create(:forum_topic)
        create(:forum_subscription, user: user, forum_topic: topic, last_read_at: 1.hour.ago)

        described_class.process_all!

        expect(UserMailer).not_to have_received(:forum_notice)
      end
    end

    context "when the topic has not been updated since last_read_at" do
      it "does not send mail" do
        topic = create(:forum_topic)
        topic.update_columns(updated_at: 2.hours.ago)
        create(:forum_subscription, forum_topic: topic, last_read_at: 1.hour.ago)

        described_class.process_all!

        expect(UserMailer).not_to have_received(:forum_notice)
      end
    end

    context "when the user is verified and the topic has new posts" do
      let(:user) { create(:user) }
      let(:topic) { create(:forum_topic) }
      let!(:subscription) { create(:forum_subscription, user: user, forum_topic: topic, last_read_at: 1.hour.ago) }

      it "sends a forum notice mail" do
        described_class.process_all!

        expect(UserMailer).to have_received(:forum_notice).with(user, topic, anything)
        expect(mail_message).to have_received(:deliver_now)
      end

      it "updates last_read_at to the topic's updated_at" do
        described_class.process_all!

        expect(subscription.reload.last_read_at).to be_within(1.second).of(topic.updated_at)
      end
    end

    context "when deliver_now raises Net::SMTPSyntaxError" do
      it "does not propagate the error" do
        topic = create(:forum_topic)
        create(:forum_subscription, forum_topic: topic, last_read_at: 1.hour.ago)
        allow(mail_message).to receive(:deliver_now).and_raise(Net::SMTPSyntaxError, "syntax error")

        expect { described_class.process_all! }.not_to raise_error
      end
    end
  end
end
