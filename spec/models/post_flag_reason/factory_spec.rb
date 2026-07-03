# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlagReason do
  include_context "as admin"

  describe "factory" do
    it "produces a valid reason with build" do
      reason = build(:post_flag_reason)
      expect(reason).to be_valid, reason.errors.full_messages.join(", ")
    end

    it "produces a persisted reason with create" do
      expect(create(:post_flag_reason)).to be_persisted
    end

    describe ":needs_staff_reason_post_flag_reason" do
      it "produces a persisted reason" do
        expect(create(:needs_staff_reason_post_flag_reason)).to be_persisted
      end

      it "has needs_staff_reason set to true" do
        expect(create(:needs_staff_reason_post_flag_reason).needs_staff_reason).to be true
      end
    end

    describe ":needs_parent_id_post_flag_reason" do
      it "produces a persisted reason" do
        expect(create(:needs_parent_id_post_flag_reason)).to be_persisted
      end

      it "has needs_parent_id set to true" do
        expect(create(:needs_parent_id_post_flag_reason).needs_parent_id).to be true
      end
    end

    describe ":needs_explanation_post_flag_reason" do
      it "produces a persisted reason" do
        expect(create(:needs_explanation_post_flag_reason)).to be_persisted
      end

      it "has needs_explanation set to true" do
        expect(create(:needs_explanation_post_flag_reason).needs_explanation).to be true
      end
    end

    describe ":grandfathering_post_flag_reason" do
      it "produces a persisted reason" do
        expect(create(:grandfathering_post_flag_reason)).to be_persisted
      end

      it "has target_date set" do
        expect(create(:grandfathering_post_flag_reason).target_date).to be_present
      end

      it "has target_date_kind set" do
        expect(create(:grandfathering_post_flag_reason).target_date_kind).to eq("after")
      end

      it "has target_tag set" do
        expect(create(:grandfathering_post_flag_reason).target_tag).to be_present
      end
    end
  end
end
