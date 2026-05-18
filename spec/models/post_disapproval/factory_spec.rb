# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        PostDisapproval Factory                              #
# --------------------------------------------------------------------------- #

RSpec.describe PostDisapproval do
  include_context "as member"

  describe "factory" do
    it "produces a valid record with build" do
      record = build(:post_disapproval)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      expect(create(:post_disapproval)).to be_persisted
    end

    it "produces a valid borderline_quality_disapproval" do
      expect(create(:borderline_quality_disapproval)).to be_persisted
    end

    it "produces a valid not_relevant_disapproval" do
      expect(create(:not_relevant_disapproval)).to be_persisted
    end

    it "produces a valid disapproval_with_message" do
      expect(create(:disapproval_with_message)).to be_persisted
    end
  end
end
