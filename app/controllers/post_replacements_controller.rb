# frozen_string_literal: true

class PostReplacementsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, only: %i[create new]
  before_action :approver_only, only: %i[approve reject promote toggle_penalize]
  before_action :admin_only, only: [:destroy]
  before_action :ensure_uploads_enabled, only: %i[new create]

  content_security_policy only: [:new] do |p|
    p.img_src :self, :data, :blob, "*"
    p.media_src :self, :data, :blob, "*"
  end

  def index
    params[:search][:post_id] = params.delete(:post_id) if params.key?(:post_id)
    @post_replacements = PostReplacement.includes(:post).visible(CurrentUser.user).search(search_params).paginate(params[:page], limit: params[:limit])

    respond_with(@post_replacements)
  end

  def new
    check_allow_create
    @post = Post.find(params[:post_id])
    @post_replacement = @post.replacements.new
    respond_with(@post_replacement)
  end

  def create
    check_allow_create
    @post = Post.find(params[:post_id])
    @post_replacement = @post.replacements.create(create_params.merge(creator_id: CurrentUser.id, creator_ip_addr: CurrentUser.ip_addr))
    @post_replacement.notify_reupload
    if @post_replacement.errors.none?
      flash.now[:notice] = "Post replacement submitted"
    end

    if CurrentUser.can_approve_posts? && !@post_replacement.upload_as_pending?
      if @post_replacement.errors.any?
        respond_to do |format|
          format.json do
            return render json: { success: false, message: @post_replacement.errors.full_messages.join("; ") }, status: 412
          end
        end
      end

      @post_replacement.approve!(penalize_current_uploader: CurrentUser.id != @post.uploader_id)
    end

    respond_to do |format|
      format.json do
        return render json: { success: false, message: @post_replacement.errors.full_messages.join("; ") }, status: 412 if @post_replacement.errors.any?

        render json: { success: true, location: post_path(@post) }
      end
    end
  end

  def approve
    @post_replacement = PostReplacement.find(params[:id])
    @post_replacement.approve!(penalize_current_uploader: params[:penalize_current_uploader])

    respond_with(@post_replacement) do |format|
      format.html { render_partial_safely("post_replacements/partials/show/post_replacement", post_replacement: @post_replacement) }
      format.json
    end
  end

  def toggle_penalize
    @post_replacement = PostReplacement.find(params[:id])
    @post_replacement.toggle_penalize!

    respond_with(@post_replacement) do |format|
      format.html { render_partial_safely("post_replacements/partials/show/post_replacement", post_replacement: @post_replacement) }
      format.json
    end
  end

  def reject
    @post_replacement = PostReplacement.find(params[:id])
    @post_replacement.reject!

    respond_with(@post_replacement) do |format|
      format.html { render_partial_safely("post_replacements/partials/show/post_replacement", post_replacement: @post_replacement) }
      format.json
    end
  end

  def destroy
    @post_replacement = PostReplacement.find(params[:id])
    @post_replacement.destroy

    respond_with(@post_replacement) do |format|
      format.html { head 200 }
      format.json
    end
  end

  def promote
    @post_replacement = PostReplacement.find(params[:id])
    @upload = @post_replacement.promote!

    object_to_respond = if @post_replacement.errors.any?
                          @post_replacement
                        else
                          @upload.errors.any? ? @upload : @upload.post
                        end

    respond_with(object_to_respond) do |format|
      format.html do
        if @post_replacement.errors.any? || @upload.errors.any?
          head 422
        else
          render_partial_safely("post_replacements/partials/show/post_replacement", post_replacement: @post_replacement)
        end
      end

      format.json
    end
  end

  private

  def check_allow_create
    return if CurrentUser.can_replace?

    raise User::PrivilegeError, "You are not part of the replacements beta"
  end

  def create_params
    params.require(:post_replacement).permit(:replacement_url, :replacement_file, :reason, :source, :as_pending)
  end

  def ensure_uploads_enabled
    access_denied if Security::Lockdown.uploads_disabled? || CurrentUser.user.level < Security::Lockdown.uploads_min_level
  end
end
