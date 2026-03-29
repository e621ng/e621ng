# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Upload::StatusMethods                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Upload do
  describe "StatusMethods" do
    # -------------------------------------------------------------------------
    # #is_pending?
    # -------------------------------------------------------------------------
    describe "#is_pending?" do
      it "returns true when status is 'pending'" do
        expect(build(:upload, status: "pending")).to be_is_pending
      end

      it "returns false when status is not 'pending'" do
        expect(build(:upload, status: "completed")).not_to be_is_pending
      end
    end

    # -------------------------------------------------------------------------
    # #is_processing?
    # -------------------------------------------------------------------------
    describe "#is_processing?" do
      it "returns true when status is 'processing'" do
        expect(build(:upload, status: "processing")).to be_is_processing
      end

      it "returns false when status is not 'processing'" do
        expect(build(:upload, status: "pending")).not_to be_is_processing
      end
    end

    # -------------------------------------------------------------------------
    # #is_completed?
    # -------------------------------------------------------------------------
    describe "#is_completed?" do
      it "returns true when status is 'completed'" do
        expect(build(:upload, status: "completed")).to be_is_completed
      end

      it "returns false when status is not 'completed'" do
        expect(build(:upload, status: "pending")).not_to be_is_completed
      end
    end

    # -------------------------------------------------------------------------
    # #is_duplicate?
    # -------------------------------------------------------------------------
    describe "#is_duplicate?" do
      it "returns true when status matches 'duplicate: <id>'" do
        expect(build(:upload, status: "duplicate: 42")).to be_is_duplicate
      end

      it "returns false when status is 'pending'" do
        expect(build(:upload, status: "pending")).not_to be_is_duplicate
      end
    end

    # -------------------------------------------------------------------------
    # #is_errored?
    # -------------------------------------------------------------------------
    describe "#is_errored?" do
      it "returns true when status begins with 'error:'" do
        expect(build(:upload, status: "error: something went wrong")).to be_is_errored
      end

      it "returns false when status is 'pending'" do
        expect(build(:upload, status: "pending")).not_to be_is_errored
      end
    end

    # -------------------------------------------------------------------------
    # #sanitized_status
    # -------------------------------------------------------------------------
    describe "#sanitized_status" do
      it "strips the DETAIL section from error statuses" do
        upload = build(:upload, status: "error: constraint failed\nDETAIL: Key (md5)=(abc) already exists.")
        expect(upload.sanitized_status).to eq("error: constraint failed\n...")
      end

      it "returns non-error statuses unchanged" do
        upload = build(:upload, status: "completed")
        expect(upload.sanitized_status).to eq("completed")
      end
    end

    # -------------------------------------------------------------------------
    # #duplicate_post_id
    # -------------------------------------------------------------------------
    describe "#duplicate_post_id" do
      it "returns the post ID string from a duplicate status" do
        upload = build(:upload, status: "duplicate: 99")
        expect(upload.duplicate_post_id).to eq("99")
      end

      it "returns nil when the status is not a duplicate" do
        upload = build(:upload, status: "pending")
        expect(upload.duplicate_post_id).to be_nil
      end
    end
  end
end
