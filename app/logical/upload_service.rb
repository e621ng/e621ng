# frozen_string_literal: true

class UploadService
  attr_reader :params, :post, :upload

  def initialize(params)
    @params = params
  end

  # Creates the Upload, checks the file (headers only) and stores the original. With async
  # processing on, the decoding steps and the post creation happen in UploadProcessingJob
  # and the upload is returned as "queued"; otherwise they run inline and the upload comes
  # back "completed" with its post. Promotions always run inline: the caller needs the post.
  def start!
    params[:tag_string] ||= "tagme"
    @upload = Upload.create(params)
    return @upload if @upload.invalid?

    begin
      @upload.transition!("processing")

      @upload.file = Utils.get_file_for_upload(@upload, file: @upload.file)
      Utils.process_file(upload, @upload.file)

      @upload.save!
    rescue Exception => x
      record_failure(x)
      return @upload
    end

    if async?
      @upload.transition!("queued")
      upload_id = @upload.id
      # The controller wraps start! in a transaction; the job must not see an uncommitted row.
      ActiveRecord.after_all_transactions_commit { UploadProcessingJob.perform_async(upload_id) }
    else
      UploadProcessingJob.new.process_upload(@upload, requeue: false, scope_user: false, file_path: @upload.file.path)
      @upload.reload
      @post = @upload.post
    end
    @upload
  end

  def warnings
    @upload&.warning_messages || []
  end

  def create_post_from_upload(upload)
    @post = convert_to_post(upload)
    @post.save!
    @post.reload

    # Posts that bypass the review queue never pass through approve!, so karma is credited here instead.
    # Mirrors the credit awarded by approve! for queued posts.
    UserStatus.adjust_karma(@post.uploader_id, UserStatus::KARMA_APPROVED_CREDIT, :queue_bypass, post_id: @post.id) unless @post.is_pending?

    upload.transition!("completed", post_id: @post.id, processing_step: nil, processed_at: Time.current)

    @post
  end

  def convert_to_post(upload)
    Post.new.tap do |p|
      p.tag_string = upload.tag_string
      p.submitted_tag_string = upload.submitted_tag_string
      p.locked_tags = upload.locked_tags
      p.is_rating_locked = true if upload.locked_rating?
      p.description = upload.description.strip
      p.md5 = upload.md5
      p.file_ext = upload.file_ext
      p.image_width = upload.image_width
      p.image_height = upload.image_height
      p.rating = upload.rating
      p.source = upload.source
      p.file_size = upload.file_size
      p.uploader_id = upload.uploader_id
      p.uploader_ip_addr = upload.uploader_ip_addr
      p.parent_id = upload.parent_id
      # Computed by Utils.process_file (is_animated, duration) and the processing job (has_sound).
      p.is_animated = upload.is_animated?
      p.duration = upload.duration
      p.has_sound = upload.has_sound?

      p.is_pending = true if should_set_pending?(upload, p)
    end
  end

  private

  def async?
    Setting.async_upload_processing? && @upload.replacement_id.blank?
  end

  # A duplicate md5 is reported as its own status so the form can link to the existing post.
  def record_failure(exception)
    duplicate = exception.is_a?(ActiveRecord::RecordInvalid) && exception.record.errors[:md5].grep(/duplicate: \d+/).first
    if duplicate
      @upload.transition!("duplicate: #{duplicate[/\d+/]}", error_message: Upload.error_message_for(exception), processed_at: Time.current)
    else
      @upload.mark_failed!(exception)
    end
  end

  def should_set_pending?(upload, post)
    return true if upload.upload_as_pending?
    return false if upload.uploader.can_approve_posts?
    return true unless upload.uploader.upload_free?
    return true if post.avoid_posting_tags.any?
    false
  end
end
