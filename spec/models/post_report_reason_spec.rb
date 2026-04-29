# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostReportReason do
  include_context "as admin"

  describe "validations" do
    it "is unique" do
      create(:post_report_reason, reason: "Inappropriate content")
      duplicate = build(:post_report_reason, reason: "Inappropriate content")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:reason]).to include("has already been taken")
    end
  end

  describe "class methods" do
    describe ".for_radio" do
      it "returns reasons in descending order of ID" do
        # Seeded reason - always expected to be there.
        reason0 = PostReportReason.find_by(reason: "Malicious File")

        reason1 = create(:post_report_reason, reason: "Reason 1")
        reason2 = create(:post_report_reason, reason: "Reason 2")
        reason3 = create(:post_report_reason, reason: "Reason 3")

        expect(PostReportReason.for_radio).to eq([reason3, reason2, reason1, reason0])
      end
    end
  end
end
