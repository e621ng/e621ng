# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlagReason do
  include_context "as admin"

  describe "validations" do
    describe "name" do
      it "is invalid when blank" do
        reason = build(:post_flag_reason, name: "")
        expect(reason).not_to be_valid
        expect(reason.errors[:name]).to be_present
      end

      it "is invalid when duplicate (case-insensitive)" do
        create(:post_flag_reason, name: "My Reason")
        duplicate = build(:post_flag_reason, name: "my reason")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include("has already been taken")
      end

      it "is invalid when set to 'deletion'" do
        reason = build(:post_flag_reason, name: "deletion")
        expect(reason).not_to be_valid
        expect(reason.errors[:name]).to be_present
      end

      it "is valid for a unique, non-reserved name" do
        reason = build(:post_flag_reason, name: "totally_fine")
        expect(reason).to be_valid
      end
    end

    describe "reason" do
      it "is invalid when blank" do
        reason = build(:post_flag_reason, reason: "")
        expect(reason).not_to be_valid
        expect(reason.errors[:reason]).to be_present
      end
    end

    describe "index" do
      it "is invalid when blank" do
        reason = build(:post_flag_reason, index: nil)
        expect(reason).not_to be_valid
        expect(reason.errors[:index]).to be_present
      end

      it "is invalid when non-integer" do
        reason = build(:post_flag_reason, index: 1.5)
        expect(reason).not_to be_valid
        expect(reason.errors[:index]).to be_present
      end

      it "is invalid when negative" do
        reason = build(:post_flag_reason, index: -1)
        expect(reason).not_to be_valid
        expect(reason.errors[:index]).to be_present
      end

      it "is valid at exactly 0" do
        reason = build(:post_flag_reason, index: 0)
        expect(reason).to be_valid
      end
    end

    describe "target_date_kind" do
      it "is invalid when set to an unrecognized value" do
        reason = build(:post_flag_reason, target_date_kind: "whenever")
        expect(reason).not_to be_valid
        expect(reason.errors[:target_date_kind]).to be_present
      end

      it "is valid when blank and target_date is also blank" do
        reason = build(:post_flag_reason, target_date: nil, target_date_kind: nil)
        expect(reason).to be_valid
      end

      it "is required when target_date is present" do
        reason = build(:post_flag_reason, target_date: Date.new(2015, 1, 1), target_date_kind: nil)
        expect(reason).not_to be_valid
        expect(reason.errors[:target_date_kind]).to be_present
      end

      it "is valid when both target_date and target_date_kind are set together" do
        reason = build(:post_flag_reason, target_date: Date.new(2015, 1, 1), target_date_kind: "after")
        expect(reason).to be_valid
      end
    end

    describe "target_date" do
      it "is required when target_date_kind is present" do
        reason = build(:post_flag_reason, target_date_kind: "before", target_date: nil)
        expect(reason).not_to be_valid
        expect(reason.errors[:target_date]).to be_present
      end
    end

    describe "target_tag" do
      it "is invalid when set to a bare dash" do
        reason = build(:post_flag_reason, target_tag: "-")
        expect(reason).not_to be_valid
        expect(reason.errors[:target_tag]).to be_present
      end

      it "is valid when set to a plain tag name" do
        reason = build(:post_flag_reason, target_tag: "some_tag")
        expect(reason).to be_valid
      end

      it "is valid when set to a negated tag name" do
        reason = build(:post_flag_reason, target_tag: "-grandfathered_content")
        expect(reason).to be_valid
      end
    end
  end
end
