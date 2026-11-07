# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadSweepJob do
  let(:live_ids) { Set.new }

  before do
    allow(UploadProcessingJob).to receive(:live_upload_ids).and_return(live_ids)
  end

  def perform
    described_class.new.perform
  end

  it "re-enqueues an upload whose job was lost mid-processing" do
    upload = create(:upload, status: "processing", processing_started_at: 25.minutes.ago, processing_step: "thumbnail")
    perform
    expect(upload.reload).to have_attributes(status: "queued", processing_step: nil)
    expect(upload.requeued_at).to be_present
    expect(UploadProcessingJob).to have_enqueued_sidekiq_job(upload.id)
  end

  it "fails an upload that was already re-enqueued once" do
    upload = create(:upload, status: "processing", processing_started_at: 25.minutes.ago, requeued_at: 1.hour.ago)
    perform
    expect(upload.reload).to have_attributes(status: "failed", error_message: "processing timed out")
    expect(upload.processed_at).to be_present
    expect(UploadProcessingJob).not_to have_enqueued_sidekiq_job(upload.id)
  end

  it "re-enqueues an upload stuck in queued" do
    upload = create(:upload, status: "queued")
    upload.update_columns(updated_at: 45.minutes.ago)
    perform
    expect(UploadProcessingJob).to have_enqueued_sidekiq_job(upload.id)
  end

  context "when Sidekiq still has the job" do
    let(:backlogged) { create(:upload, status: "queued") }
    let(:running) { create(:upload, status: "processing", processing_started_at: 25.minutes.ago, requeued_at: 1.hour.ago) }
    let(:live_ids) { Set[backlogged.id, running.id] }

    it "leaves the uploads alone" do
      backlogged.update_columns(updated_at: 45.minutes.ago)
      running
      perform
      expect(backlogged.reload.status).to eq("queued")
      expect(running.reload.status).to eq("processing")
      expect(UploadProcessingJob).not_to have_enqueued_sidekiq_job(backlogged.id)
    end
  end

  it "leaves an upload alone that finished while Sidekiq was being scanned" do
    upload = create(:upload, status: "processing", processing_started_at: 25.minutes.ago)
    allow(UploadProcessingJob).to receive(:live_upload_ids) do
      upload.transition!("completed", post_id: 1)
      Set.new
    end
    perform
    expect(upload.reload).to have_attributes(status: "completed", requeued_at: nil)
    expect(UploadProcessingJob).not_to have_enqueued_sidekiq_job(upload.id)
  end

  it "does not consult Sidekiq when nothing is stale" do
    create(:upload, status: "queued")
    perform
    expect(UploadProcessingJob).not_to have_received(:live_upload_ids)
  end

  it "fails an upload abandoned by its request before the job took over" do
    upload = create(:upload, status: "processing", processing_started_at: nil)
    upload.update_columns(updated_at: 15.minutes.ago)
    perform
    expect(upload.reload).to have_attributes(status: "failed", error_message: "processing timed out")
    expect(UploadProcessingJob).not_to have_enqueued_sidekiq_job(upload.id)
  end

  it "leaves fresh and finished uploads alone" do
    in_request = create(:upload, status: "processing", processing_started_at: nil)
    in_request.update_columns(updated_at: 2.minutes.ago)
    fresh = create(:upload, status: "processing", processing_started_at: 1.minute.ago)
    queued = create(:upload, status: "queued")
    done = create(:upload, status: "completed")
    perform
    expect(fresh.reload.status).to eq("processing")
    expect(in_request.reload.status).to eq("processing")
    expect(queued.reload.status).to eq("queued")
    expect(done.reload.status).to eq("completed")
    expect(UploadProcessingJob).not_to have_enqueued_sidekiq_job(fresh.id)
  end
end
