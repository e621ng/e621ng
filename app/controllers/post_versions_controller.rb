# frozen_string_literal: true

class PostVersionsController < ApplicationController
  before_action :member_only, except: [:index]
  respond_to :html, :json
  respond_to :js, only: [:undo]

  def index
    @post_versions = PostVersion.search(search_params).paginate(params[:page], limit: params[:limit], max_count: 10_000, search_count: params[:search], includes: [:updater, { post: [:versions] }])
    if CurrentUser.is_staff?
      ids = @post_versions&.map(&:id)
      @latest = request.params.merge(page: "b#{ids[0] + 1}") if ids.present?
    end
    respond_with(@post_versions)
  end

  def undo
    can_edit = CurrentUser.can_post_edit_with_reason
    raise User::PrivilegeError, "Updater #{User.throttle_reason(can_edit)}" unless can_edit == true

    @post_version = PostVersion.find(params[:id])
    @post_version.undo!
  end

  def hide
    raise User::PrivilegeError unless CurrentUser.is_admin?

    @post_version = PostVersion.find(params[:id])
    @post_version.is_hidden = true
    @post_version.save!
    ModAction.log(:post_version_hide, { version: @post_version.version, post_id: @post_version.post_id })

    redirect_back fallback_location: post_versions_path(search: { post_id: @post_version.post_id })
  end

  def unhide
    raise User::PrivilegeError unless CurrentUser.is_admin?

    @post_version = PostVersion.find(params[:id])
    @post_version.is_hidden = false
    @post_version.save!
    ModAction.log(:post_version_unhide, { version: @post_version.version, post_id: @post_version.post_id })

    redirect_back fallback_location: post_versions_path(search: { post_id: @post_version.post_id })
  end
end
