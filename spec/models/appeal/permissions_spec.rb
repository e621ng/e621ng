# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # APIMethods#hidden_attributes
  # -------------------------------------------------------------------------
  describe "#hidden_attributes" do
    let(:appeal) { create(:appeal) }

    context "when CurrentUser is an unrelated member (non-viewer)" do
      let(:member) { create(:user) }

      before do
        appeal # ensure created as admin before switching
        CurrentUser.user = member
      end

      after { CurrentUser.user = nil }

      it "hides creator_id" do
        expect(appeal.hidden_attributes).to include(:creator_id)
      end

      it "hides accused_id" do
        expect(appeal.hidden_attributes).to include(:accused_id)
      end

      it "hides reason" do
        expect(appeal.hidden_attributes).to include(:reason)
      end

      it "hides response" do
        expect(appeal.hidden_attributes).to include(:response)
      end
    end

    context "when CurrentUser is the appeal creator (non-staff member)" do
      let(:member_creator) { create(:user) }
      let(:member_appeal) do
        old = CurrentUser.user
        CurrentUser.user = member_creator
        a = create(:appeal)
        CurrentUser.user = old
        a
      end

      before { CurrentUser.user = member_creator }
      after  { CurrentUser.user = nil }

      it "does not hide creator_id" do
        expect(member_appeal.hidden_attributes).not_to include(:creator_id)
      end

      it "does not hide reason" do
        expect(member_appeal.hidden_attributes).not_to include(:reason)
      end

      it "hides claimant_id" do
        expect(member_appeal.hidden_attributes).to include(:claimant_id)
      end
    end

    context "when CurrentUser is a janitor" do
      before { CurrentUser.user = create(:janitor_user) }
      after  { CurrentUser.user = nil }

      it "does not hide creator_id" do
        expect(appeal.hidden_attributes).not_to include(:creator_id)
      end

      it "does not hide reason" do
        expect(appeal.hidden_attributes).not_to include(:reason)
      end

      it "does not hide claimant_id" do
        expect(appeal.hidden_attributes).not_to include(:claimant_id)
      end
    end
  end

  # -------------------------------------------------------------------------
  # AppealTypes::Flag#can_view?
  # -------------------------------------------------------------------------
  describe "#can_view? (flag type)" do
    let(:appeal) { create(:appeal) }

    it "returns true for staff" do
      expect(appeal.can_view?(create(:janitor_user))).to be true
    end

    it "returns true for the appeal creator" do
      expect(appeal.can_view?(appeal.creator)).to be true
    end

    it "returns false for an unrelated member" do
      expect(appeal.can_view?(create(:user))).to be false
    end
  end
end
