class PostVersionsController < ApplicationController
  before_action :member_only
  respond_to :html, :json
  respond_to :js, only: [:undo]

  def index
    @post_versions = PostArchive.search(PostArchive.build_query(search_params)).paginate(params[:page], :limit => params[:limit], :search_count => params[:search], includes: [:updater, post: [:versions]])
    respond_with(@post_versions)
  end

  def search
  end

  def undo
    can_edit = CurrentUser.can_post_edit_with_reason
    raise User::PrivilegeError.new("Updater #{User.throttle_reason(can_edit)}") unless can_edit == true

    @post_version = PostArchive.find(params[:id])
    @post_version.undo!

    redirect_back fallback_location: post_versions_path
  end
end
