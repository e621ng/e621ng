# frozen_string_literal: true

class UploadsController < ApplicationController
  before_action :member_only
  before_action :staff_only, only: [:index]
  before_action :ensure_uploads_enabled, only: %i[new create]
  respond_to :html, :json
  content_security_policy only: [:new] do |p|
    p.img_src :self, :data, :blob, "*"
    p.media_src :self, :data, :blob, "*"
  end

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

  private

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
