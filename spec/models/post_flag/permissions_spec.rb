# frozen_string_literal: true

require "rails_helper"

# Tests for ApiMethods: hidden_attributes and method_attributes

RSpec.describe PostFlag do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # hidden_attributes
  # -------------------------------------------------------------------------
  describe "#hidden_attributes" do
    let(:flag_reason) { create(:post_flag_reason) }
    let(:flag)        { create(:post_flag, reason_name: flag_reason.name) }

    context "when CurrentUser cannot view the flagger (regular member, not the creator)" do
      let(:member) { create(:user) }

      before do
        flag # ensure flag is created as admin before switching to member
        CurrentUser.user = member
      end

      after { CurrentUser.user = nil }

      it "includes :creator_id in hidden attributes" do
        expect(flag.hidden_attributes).to include(:creator_id)
      end
    end

    context "when CurrentUser is a janitor" do
      before { CurrentUser.user = create(:janitor_user) }
      after  { CurrentUser.user = nil }

      it "does not hide :creator_id" do
        expect(flag.hidden_attributes).not_to include(:creator_id)
      end
    end

    context "when CurrentUser is the flag creator" do
      before { CurrentUser.user = flag.creator }
      after  { CurrentUser.user = nil }

      it "does not hide :creator_id" do
        expect(flag.hidden_attributes).not_to include(:creator_id)
      end
    end

    context "for a deletion flag" do
      let(:deletion_flag) { create(:deletion_post_flag) }
      let(:member)        { create(:user) }

      before { CurrentUser.user = member }
      after  { CurrentUser.user = nil }

      # can_view_flagger_on_post? returns true for is_deletion flags
      it "does not hide :creator_id on deletion flags" do
        expect(deletion_flag.hidden_attributes).not_to include(:creator_id)
      end
    end

    context "note visibility with default config (:staff)" do
      let(:member) { create(:user) }

      before do
        flag # ensure flag is created as admin before switching to member
        CurrentUser.user = member
      end

      after { CurrentUser.user = nil }

      it "hides :note for a regular member who is not the creator" do
        expect(flag.hidden_attributes).to include(:note)
      end
    end

    context "note visibility when CurrentUser is staff" do
      before { CurrentUser.user = create(:janitor_user) }
      after  { CurrentUser.user = nil }

      it "does not hide :note for staff" do
        expect(flag.hidden_attributes).not_to include(:note)
      end
    end

    context "note visibility when CurrentUser is the flag creator" do
      before { CurrentUser.user = flag.creator }
      after  { CurrentUser.user = nil }

      it "does not hide :note for the flag creator" do
        expect(flag.hidden_attributes).not_to include(:note)
      end
    end
  end

  # -------------------------------------------------------------------------
  # method_attributes
  # -------------------------------------------------------------------------
  describe "#method_attributes" do
    it "includes :type in the method attributes list" do
      create(:post_flag_reason)
      flag = create(:post_flag)
      expect(flag.method_attributes).to include(:type)
    end
  end
end
