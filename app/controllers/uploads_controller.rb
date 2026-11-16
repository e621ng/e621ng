# frozen_string_literal: true

class UploadsController < ApplicationController
  before_action :member_only
  before_action :staff_only, only: [:index]
  before_action :ensure_uploads_enabled, only: %i[new create]
  before_action :reject_api_key_auth, :reject_bearer_auth, :same_origin_only, only: [:preview]
  respond_to :html, :json
  content_security_policy only: [:new] do |p|
    p.img_src :self, :data, :blob, "*"
    p.media_src :self, :data, :blob, "*"
  end
  # Third-party bytes served from our origin: never let them run as a document.
  content_security_policy only: [:preview] do |p|
    p.default_src :none
    p.sandbox
  end

  PREVIEW_MAX_SIZE = 25.megabytes
  PREVIEW_DEADLINE = 20 # seconds
  PREVIEW_MIME_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  def index
    @uploads = Upload.search(search_params).includes(:post, :uploader).paginate(params[:page], :limit => params[:limit])
    Post.preload_stats!(@uploads.map(&:post))
    respond_with(@uploads)
  end

  # The uploader polls this while their upload is processed; staff can see any upload.
  def show
    @upload = Upload.find(params[:id])
    raise User::PrivilegeError unless @upload.uploader_id == CurrentUser.id || CurrentUser.is_staff?

    respond_with(@upload) do |format|
      format.html do
        if @upload.is_completed? && @upload.post_id
          redirect_to(post_path(@upload.post_id))
        end
      end
    end
  end

  def new
    if CurrentUser.can_upload_with_reason == :REJ_UPLOAD_NEWBIE
      return access_denied("You can not upload during your first week.")
    end
    @upload = Upload.new
    respond_with(@upload)
  end

  def create
    Post.transaction do
      @service = UploadService.new(upload_params)
      @upload = @service.start!
    end

    if @upload.invalid?
      flash[:notice] = @upload.errors.full_messages.join("; ")
      return render json: {success: false, reason: 'invalid', message: @upload.errors.full_messages.join("; ")}, status: 412
    end
    # Only when the post was created in this request; asynchronous uploads carry their warnings in the poll response.
    if @upload.is_completed? && @upload.warning_messages.any?
      flash[:notice] = @upload.warning_messages.join(".\n \n")
    end
    # Set by DocumentStore when the new post's OpenSearch write was deferred; only reachable inline.
    if @upload.is_completed? && RequestStore[:index_update_delayed]
      notice = "Search indexing is temporarily delayed. The post will appear in searches shortly."
      flash[:notice] = [flash[:notice].presence, notice].compact.join("\n\n")
    end

    respond_to do |format|
      format.json do
        return render json: {success: false, reason: 'duplicate', location: post_path(@upload.duplicate_post_id), post_id: @upload.duplicate_post_id}, status: 412 if @upload.is_duplicate?
        return render json: {success: false, reason: 'invalid', message: @upload.error_message}, status: 412 if @upload.is_failed?

        if @upload.is_completed?
          render json: {success: true, location: post_path(@upload.post_id), post_id: @upload.post_id, upload_id: @upload.id}
        else
          render json: {success: true, location: upload_path(@upload.id), upload_id: @upload.id}
        end
      end
    end
  end

  # Fetches the preview of a URL from a site that refuses hotlinks, sending the strategy's
  # headers. The uploader falls back to this when loading the file directly fails.
  def preview
    url = params[:url]
    return head(400) unless url.is_a?(String)

    download = Downloads::File.new(url)
    return head(404) unless download.strategy.hotlink_protected?

    throttle_preview!
    file = download.download!(max_size: PREVIEW_MAX_SIZE, retries: 0, deadline: PREVIEW_DEADLINE)
    mime_type = Marcel::MimeType.for(file)
    return head(422) unless mime_type.in?(PREVIEW_MIME_TYPES)

    file.rewind
    response.headers["Cache-Control"] = "private, no-store"
    send_data(file.read, type: mime_type, disposition: "inline")
  rescue Downloads::File::Error
    head(422)
  ensure
    file&.close!
  end

  private

  def same_origin_only
    site = request.headers["Sec-Fetch-Site"]
    head(403) if site.present? && site != "same-origin"
  end

  def throttle_preview!
    return if Danbooru.config.disable_throttles?

    limiters = [
      RateLimiter.new("upload_preview:user:#{CurrentUser.id}", limit: 30, period: 10.minutes),
      RateLimiter.new("upload_preview:ip:#{CurrentUser.ip_addr}", limit: 30, period: 10.minutes),
    ]
    raise APIThrottled if limiters.any?(&:throttled?)
    limiters.each(&:hit!)
  end

  def upload_params
    permitted_params = %i[
      file direct_url source tag_string rating parent_id description as_pending
    ]

    permitted_params << :locked_tags if CurrentUser.is_admin?
    permitted_params << :locked_rating if CurrentUser.is_privileged?

    params.require(:upload).permit(permitted_params).merge(uploader_id: CurrentUser.id, uploader_ip_addr: CurrentUser.ip_addr)
  end

  def ensure_uploads_enabled
    access_denied if Security::Lockdown.uploads_disabled? || CurrentUser.user.level < Security::Lockdown.uploads_min_level
  end
end
