# frozen_string_literal: true

# Decodes an uploaded file and turns the upload into a post, outside the web request:
# integrity check, previews/samples, sound detection, then Post creation. Also regenerates
# previews for an existing post (mode "post"). Runs on the "uploads" queue, which production
# serves from the media container alongside video/thumb.
#
# UploadService#start! runs the same steps inline when async processing is off, so there is
# one code path for both modes.
class UploadProcessingJob < ApplicationJob
  LOCK_TTL = 2.hours
  REQUEUE_DELAY = 30.seconds
  STEPS = %w[integrity thumbnail sound post].freeze

  # Full args as the lock key: [upload_id] and [post_id, "post"] must not collide.
  # until_and_while_executing + reschedule: a second request while one runs is pushed back, not dropped.
  # Retries are handled here (see rescue in process_upload), not by Sidekiq.
  sidekiq_options queue: "uploads", lock: :until_and_while_executing, lock_args_method: :lock_args,
                  lock_ttl: LOCK_TTL.to_i, on_conflict: { server: :reschedule }, schedule_in: 30, retry: 0

  def self.lock_args(args)
    args
  end

  # Upload ids with a job waiting on the queue, scheduled (requeue, reschedule) or running on
  # any Sidekiq process. UploadSweepJob treats a stale upload absent from this set as lost.
  def self.live_upload_ids
    jobs = Sidekiq::Queue.new(get_sidekiq_options["queue"]).to_a + Sidekiq::ScheduledSet.new.to_a
    jobs += Sidekiq::Workers.new.map { |_pid, _tid, work| work.job }
    jobs.filter_map { |job| job.args.first if job.klass == name && job.args.second.to_s.in?(["", "upload"]) }.to_set
  end

  def perform(id, mode = "upload")
    case mode
    when "upload"
      # Already pruned by DailyPruneJob, or never committed.
      process_upload(Upload.find_by(id: id), requeue: true, scope_user: true)
    when "post"
      post = Post.find_by(id: id)
      ImageSampler.generate_post_images(post) if post
    else
      raise ArgumentError, "unknown mode #{mode.inspect}"
    end
  end

  # requeue: a timeout gets one more attempt 30 s later; false fails immediately (the inline
  # path can't wait). scope_user: act as the uploader; false keeps the caller's CurrentUser
  # (the inline path runs inside a request that already has one).
  # file_path: where to read the original from; defaults to its place in storage.
  def process_upload(upload, requeue:, scope_user:, file_path: nil)
    return if upload.nil? || upload.is_completed? || upload.is_failed? || upload.is_duplicate? || upload.post_id.present?

    upload.transition!("processing", processing_started_at: Time.current, processing_step: nil)
    path = file_path || Danbooru.config.storage_manager.post_file_path(upload.media_stub)
    raise UploadService::Utils::MissingFileError, "original file is missing from storage" unless File.exist?(path)

    step(upload, "integrity") { check_integrity(upload, path) }
    step(upload, "thumbnail") { ImageSampler.generate_post_images(upload.media_stub) }
    step(upload, "sound") { upload.update_columns(has_sound: upload.is_video? && upload.video_has_sound?(path)) }
    step(upload, "post") { create_post(upload, scope_user: scope_user) }
  rescue StandardError, Upload::Error => e
    # Not Exception: Sidekiq::Shutdown must propagate so a drained job is picked up by the sweep.
    if requeue && timeout?(e) && upload.requeued_at.nil?
      upload.transition!("queued", requeued_at: Time.current, processing_step: nil)
      self.class.perform_in(REQUEUE_DELAY, upload.id)
    else
      DanbooruLogger.log(e, expected: expected?(e))
      upload.mark_failed!(e)
    end
  end

  private

  def step(upload, name)
    upload.update_columns(processing_step: name, updated_at: Time.current)
    yield
  end

  def check_integrity(upload, path)
    FileValidator.new(upload, path).validate_file_integrity
    raise UploadService::Utils::CorruptFileError, "file is corrupt" if upload.errors.any?
  end

  def create_post(upload, scope_user:)
    if scope_user
      CurrentUser.scoped(upload.uploader, upload.uploader_ip_addr.to_s) { create_post_now(upload) }
    else
      create_post_now(upload)
    end
  end

  def create_post_now(upload)
    # Savepoint: when this runs inside the request's Post.transaction a failure here must not
    # abort that transaction, or mark_failed! could not write.
    Post.transaction(requires_new: true) do
      existing = Post.find_by(md5: upload.md5)
      if existing
        # A racing path (or a crash after the post committed) already made the post.
        upload.transition!("duplicate: #{existing.id}", processing_step: nil, processed_at: Time.current)
      else
        post = UploadService.new({}).create_post_from_upload(upload)
        record_warnings(upload, post)
      end
    end
  end

  # Tag notices for the uploader. The poll response carries them; very long lists are dmailed instead.
  def record_warnings(upload, post)
    warnings = post.warnings.full_messages
    return if warnings.empty?

    joined = warnings.join(".\n \n")
    if joined.length > 1500
      Dmail.create_automated(
        to_id: upload.uploader_id,
        title: "Upload notices for post ##{post.id}",
        body: "While uploading post ##{post.id} some notices were generated. Please review them below:\n\n#{joined}",
      )
      warnings = ["This upload created a LOT of notices. They have been dmailed to you. Please review them"]
    end
    upload.update_columns(warning_messages: warnings)
  end

  def timeout?(exception)
    exception.is_a?(ExternalCommand::TimeoutError) || exception.is_a?(VipsCommand::TimeoutError)
  end

  def expected?(exception)
    exception.is_a?(UploadService::Utils::CorruptFileError) || exception.is_a?(ActiveRecord::RecordInvalid) || timeout?(exception)
  end
end
