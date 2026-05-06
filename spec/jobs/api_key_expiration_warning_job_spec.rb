# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKeyExpirationWarningJob do
  include_context "as admin"

  def perform
    described_class.perform_now
  end

  describe "#perform" do
    context "when there are no API keys expiring soon" do
      it "sends no emails" do
        expect { perform }.not_to(change { ActionMailer::Base.deliveries.count })
      end
    end

    context "when there is one API key expiring soon" do
      let!(:api_key) { create(:expiring_soon_api_key) }

      it "sends one expiration notice email" do
        expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "addresses the email to the key owner" do
        perform
        expect(ActionMailer::Base.deliveries.last.to).to include(api_key.user.email)
      end

      it "sets notified_at on the key" do
        expect { perform }.to change { api_key.reload.notified_at }.from(nil)
      end
    end

    context "when there are multiple API keys expiring soon" do
      let!(:api_keys) { create_list(:expiring_soon_api_key, 3) }

      it "sends an email for each key" do
        expect { perform }.to change { ActionMailer::Base.deliveries.count }.by(3)
      end

      it "sets notified_at on all keys" do
        perform
        api_keys.each { |key| expect(key.reload.notified_at).not_to be_nil }
      end
    end

    context "when an API key has already been notified" do
      let!(:api_key) { create(:expiring_soon_api_key, notified_at: 1.day.ago) }

      it "does not send an email" do
        expect { perform }.not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "does not update notified_at" do
        original = api_key.notified_at
        perform
        expect(api_key.reload.notified_at).to be_within(1.second).of(original)
      end
    end

    context "when an API key expires more than 7 days from now" do
      before { create(:api_key, expires_at: 10.days.from_now) }

      it "does not send an email" do
        expect { perform }.not_to(change { ActionMailer::Base.deliveries.count })
      end
    end

    context "when an API key is already expired" do
      before { create(:expired_api_key) }

      it "does not send an email" do
        expect { perform }.not_to(change { ActionMailer::Base.deliveries.count })
      end
    end

    context "when an API key has no expiration date" do
      before { create(:api_key, expires_at: nil) }

      it "does not send an email" do
        expect { perform }.not_to(change { ActionMailer::Base.deliveries.count })
      end
    end
  end
end
