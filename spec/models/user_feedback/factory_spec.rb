# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Factory sanity checks                             #
# --------------------------------------------------------------------------- #

RSpec.describe UserFeedback do
  # belongs_to_updater sets updater_id = CurrentUser.id on every before_validation.
  # ModAction.log (after_create callback) also reads CurrentUser.id for its creator.
  # Wrapping all examples in a moderator scope satisfies both requirements cleanly.
  let(:moderator) { create(:moderator_user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "factory" do
    it "produces a valid user_feedback" do
      expect(create(:user_feedback)).to be_persisted
    end

    it "produces a valid neutral user_feedback" do
      expect(create(:neutral_user_feedback)).to be_persisted
    end

    it "produces a valid negative user_feedback" do
      expect(create(:negative_user_feedback)).to be_persisted
    end

    it "produces a valid deleted user_feedback" do
      expect(create(:deleted_user_feedback)).to be_persisted
    end
  end
end
