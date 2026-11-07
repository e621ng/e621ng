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
    # #is_queued? / #is_failed? / #is_in_flight?
    # -------------------------------------------------------------------------
    describe "#is_queued?" do
      it "returns true when status is 'queued'" do
        expect(build(:upload, status: "queued")).to be_is_queued
      end

      it "returns false when status is 'pending'" do
        expect(build(:upload, status: "pending")).not_to be_is_queued
      end
    end

    describe "#is_failed?" do
      it "returns true when status is 'failed'" do
        expect(build(:upload, status: "failed")).to be_is_failed
      end

      it "returns false when status is 'pending'" do
        expect(build(:upload, status: "pending")).not_to be_is_failed
      end
    end

    describe "#is_in_flight?" do
      it "returns true for queued and processing" do
        expect(build(:upload, status: "queued")).to be_is_in_flight
        expect(build(:upload, status: "processing")).to be_is_in_flight
      end

      it "returns false for terminal statuses" do
        expect(build(:upload, status: "completed")).not_to be_is_in_flight
        expect(build(:upload, status: "failed")).not_to be_is_in_flight
        expect(build(:upload, status: "pending")).not_to be_is_in_flight
      end
    end

    # -------------------------------------------------------------------------
    # #transition! / #mark_failed!
    # -------------------------------------------------------------------------
    describe "#transition!" do
      it "writes the status and extra columns without validation" do
        upload = create(:upload, status: "pending")
        upload.transition!("queued", processing_step: "integrity")
        expect(upload.reload).to have_attributes(status: "queued", processing_step: "integrity")
      end
    end

    describe "#mark_failed!" do
      let(:upload) { create(:upload, status: "processing", processing_step: "thumbnail") }

      it "uses the record's validation messages for RecordInvalid" do
        invalid = build(:upload, rating: "z")
        invalid.valid?
        upload.mark_failed!(ActiveRecord::RecordInvalid.new(invalid))
        expect(upload.reload).to have_attributes(status: "failed", error_message: a_string_including("Rating"), processing_step: nil)
        expect(upload.processed_at).to be_present
      end

      it "uses the message as-is for corrupt files" do
        upload.mark_failed!(UploadService::Utils::CorruptFileError.new("file is corrupt"))
        expect(upload.reload.error_message).to eq("file is corrupt")
      end

      it "reports a timeout plainly" do
        upload.mark_failed!(ExternalCommand::TimeoutError.new("ffmpeg timed out after 45 seconds"))
        expect(upload.reload.error_message).to eq("processing timed out")
      end

      it "strips the DETAIL section from other errors and keeps the backtrace" do
        error = RuntimeError.new("constraint failed\nDETAIL: Key (md5)=(abc) already exists.")
        error.set_backtrace(%w[a.rb:1 b.rb:2])
        upload.mark_failed!(error)
        expect(upload.reload).to have_attributes(error_message: "RuntimeError - constraint failed\n...", backtrace: "a.rb:1\nb.rb:2")
      end
    end

    # -------------------------------------------------------------------------
    # #duplicate_post_id
    # -------------------------------------------------------------------------
    describe "#duplicate_post_id" do
      it "returns the post ID from a duplicate status" do
        upload = build(:upload, status: "duplicate: 99")
        expect(upload.duplicate_post_id).to eq(99)
      end

      it "returns nil when the status is not a duplicate" do
        upload = build(:upload, status: "pending")
        expect(upload.duplicate_post_id).to be_nil
      end
    end
  end
end
