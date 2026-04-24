# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequest do
  include_context "as admin"

  let(:creator) { create(:user) }
  let(:admin)   { create(:admin_user) }
  let(:member)  { create(:user) }

  let(:pending_bur) do
    bur = create(:bulk_update_request, user: creator)
    bur
  end

  let(:approved_bur) { create(:approved_bulk_update_request, user: creator) }
  let(:rejected_bur) { create(:rejected_bulk_update_request, user: creator) }

  describe "#editable?" do
    it "is true for the creator when pending" do
      expect(pending_bur.editable?(creator)).to be true
    end

    it "is true for an admin when pending" do
      expect(pending_bur.editable?(admin)).to be true
    end

    it "is false for a non-creator non-admin member" do
      expect(pending_bur.editable?(member)).to be false
    end

    it "is false for the creator when approved" do
      expect(approved_bur.editable?(creator)).to be false
    end

    it "is false for the creator when rejected" do
      expect(rejected_bur.editable?(creator)).to be false
    end
  end

  describe "#approvable?" do
    it "is true for an admin when pending" do
      expect(pending_bur.approvable?(admin)).to be true
    end

    it "is false for a non-admin member when pending" do
      expect(pending_bur.approvable?(member)).to be false
    end

    it "is false for an admin when approved" do
      expect(approved_bur.approvable?(admin)).to be false
    end

    it "is false for an admin when rejected" do
      expect(rejected_bur.approvable?(admin)).to be false
    end
  end

  describe "#rejectable?" do
    it "is true for the creator when pending" do
      expect(pending_bur.rejectable?(creator)).to be true
    end

    it "is true for an admin when pending" do
      expect(pending_bur.rejectable?(admin)).to be true
    end

    it "is false for a non-creator non-admin member when pending" do
      expect(pending_bur.rejectable?(member)).to be false
    end

    it "is false when not pending" do
      expect(approved_bur.rejectable?(creator)).to be false
      expect(rejected_bur.rejectable?(creator)).to be false
    end
  end
end
