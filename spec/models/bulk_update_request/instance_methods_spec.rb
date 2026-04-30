# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequest do
  include_context "as admin"

  let(:bur) { create(:bulk_update_request) }

  describe "#is_pending?" do
    it "returns true when status is pending" do
      expect(bur.is_pending?).to be true
    end

    it "returns false when status is approved" do
      bur.update_columns(status: "approved")
      expect(bur.is_pending?).to be false
    end
  end

  describe "#is_approved?" do
    it "returns false when status is pending" do
      expect(bur.is_approved?).to be false
    end

    it "returns true when status is approved" do
      bur.update_columns(status: "approved")
      expect(bur.is_approved?).to be true
    end
  end

  describe "#is_rejected?" do
    it "returns false when status is pending" do
      expect(bur.is_rejected?).to be false
    end

    it "returns true when status is rejected" do
      bur.update_columns(status: "rejected")
      expect(bur.is_rejected?).to be true
    end
  end

  describe "#dtext_label" do
    it "returns the correct dtext embed string" do
      expect(bur.dtext_label).to eq("[bur:#{bur.id}]")
    end
  end

  describe "#bulk_update_request_link" do
    it "returns a dtext link to the BUR" do
      expect(bur.bulk_update_request_link).to eq(%("bulk update request ##{bur.id}":/bulk_update_requests/#{bur.id}))
    end
  end

  describe "#reason_with_link" do
    it "includes the bur embed and the reason text" do
      bur.reason = "My test reason"
      expect(bur.reason_with_link).to eq("[bur:#{bur.id}]\n\nReason: My test reason")
    end
  end

  describe "#skip_forum=" do
    it "coerces the string 'true' to true" do
      bur.skip_forum = "true"
      expect(bur.skip_forum).to be true
    end

    it "coerces the string 'false' to false" do
      bur.skip_forum = "false"
      expect(bur.skip_forum).to be false
    end
  end

  describe "#estimate_update_count" do
    it "returns a non-negative integer" do
      expect(bur.estimate_update_count).to be >= 0
    end

    it "delegates to BulkUpdateRequestImporter" do
      bur # create before stubbing so factory's validate_script is unaffected
      importer_double = instance_double(BulkUpdateRequestImporter)
      allow(BulkUpdateRequestImporter).to receive(:new).and_return(importer_double)
      allow(importer_double).to receive(:estimate_update_count).and_return(42)
      expect(bur.estimate_update_count).to eq(42)
    end
  end

  describe "#creator_id" do
    it "is an alias for user_id" do
      expect(bur.creator_id).to eq(bur.user_id)
    end
  end
end
