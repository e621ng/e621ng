# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserFeedbackMailJob do
  include_context "as admin"

  def perform(user_id, feedback_id)
    described_class.new.perform(user_id, feedback_id)
  end

  describe "#perform" do
    let(:feedback) { create(:user_feedback) }

    it "sends one feedback notice email to the user" do
      expect { perform(feedback.user_id, feedback.id) }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to include(feedback.user.email)
    end

    it "does nothing when the user no longer exists" do
      expect { perform(-1, feedback.id) }
        .not_to(change { ActionMailer::Base.deliveries.count })
    end

    it "does nothing when the feedback no longer exists" do
      expect { perform(feedback.user_id, -1) }
        .not_to(change { ActionMailer::Base.deliveries.count })
    end
  end
end
