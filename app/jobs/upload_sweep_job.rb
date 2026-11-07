# frozen_string_literal: true

# Uploads whose processing job was lost (media container OOM/restart, Sidekiq OSS has no
# fetch recovery) would otherwise sit in "processing" forever. One lost run is re-enqueued;
# a second loss fails the upload so the uploader sees something instead of a stuck page.
#
# In-flight uploads count against the uploader's limits and block re-uploading the same
# file, so a stuck row is no longer harmless: everything the sweep misses costs the user
# until DailyPruneJob deletes it a week later.
class UploadSweepJob < ApplicationJob
  sidekiq_options queue: "low_prio", lock: :until_executed, lock_ttl: 10.minutes.to_i

  # Sum of the processing step bounds (~5.5 min) plus headroom for a CPU-starved media container.
  PROCESSING_TIMEOUT = 20.minutes
  QUEUED_TIMEOUT = 30.minutes
  # UploadService#start! sets "processing" (no processing_started_at) for the request phase,
  # which Pitchfork bounds at 180 s. Nothing is stored yet for such a row, so it cannot be retried.
  REQUEST_TIMEOUT = 10.minutes

  def perform
    stale = Upload.where(status: "processing").where(processing_started_at: ...PROCESSING_TIMEOUT.ago)
                  .or(Upload.where(status: "queued").where(updated_at: ...QUEUED_TIMEOUT.ago))

    stale.find_each do |upload|
      if upload.requeued_at.nil?
        upload.transition!("queued", requeued_at: Time.current, processing_step: nil)
        UploadProcessingJob.perform_async(upload.id)
      else
        fail_upload(upload)
      end
    end

    Upload.where(status: "processing", processing_started_at: nil).where(updated_at: ...REQUEST_TIMEOUT.ago).find_each do |upload|
      fail_upload(upload)
    end
  end

  private

  def fail_upload(upload)
    upload.transition!("failed", error_message: "processing timed out", processing_step: nil, processed_at: Time.current)
  end
end
