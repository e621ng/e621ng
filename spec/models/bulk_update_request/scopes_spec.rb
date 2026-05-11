# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequest do
  include_context "as admin"

  describe ".pending scope" do
    let!(:pending_bur)  { create(:bulk_update_request) }
    let!(:approved_bur) { create(:approved_bulk_update_request) }
    let!(:rejected_bur) { create(:rejected_bulk_update_request) }

    it "includes pending records" do
      expect(BulkUpdateRequest.pending).to include(pending_bur)
    end

    it "excludes approved records" do
      expect(BulkUpdateRequest.pending).not_to include(approved_bur)
    end

    it "excludes rejected records" do
      expect(BulkUpdateRequest.pending).not_to include(rejected_bur)
    end
  end

  describe ".pending_first scope" do
    let!(:approved_bur) { create(:approved_bulk_update_request) }
    let!(:rejected_bur) { create(:rejected_bulk_update_request) }
    let!(:pending_bur)  { create(:bulk_update_request) }

    it "orders pending before approved before rejected" do
      ids = BulkUpdateRequest.pending_first.ids
      expect(ids.index(pending_bur.id)).to be < ids.index(approved_bur.id)
      expect(ids.index(approved_bur.id)).to be < ids.index(rejected_bur.id)
    end
  end

  describe ".default_order" do
    let!(:first_pending)  { create(:bulk_update_request) }
    let!(:second_pending) { create(:bulk_update_request) }
    let!(:approved_bur)   { create(:approved_bulk_update_request) }

    it "places pending records before approved records" do
      ids = BulkUpdateRequest.default_order.ids
      expect(ids.index(first_pending.id)).to be < ids.index(approved_bur.id)
      expect(ids.index(second_pending.id)).to be < ids.index(approved_bur.id)
    end

    it "orders newer id first within the same status" do
      ids = BulkUpdateRequest.default_order.ids
      expect(ids.index(second_pending.id)).to be < ids.index(first_pending.id)
    end
  end
end
