# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequest do
  include_context "as admin"

  describe "factory" do
    it "creates a valid pending record" do
      expect(create(:bulk_update_request)).to be_valid
    end

    it "creates an approved record via :approved_bulk_update_request" do
      expect(create(:approved_bulk_update_request).status).to eq("approved")
    end

    it "creates a rejected record via :rejected_bulk_update_request" do
      expect(create(:rejected_bulk_update_request).status).to eq("rejected")
    end
  end
end
