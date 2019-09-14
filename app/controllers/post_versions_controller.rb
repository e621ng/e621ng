class PostVersionsController < ApplicationController
  before_action :member_only
  respond_to :html, :xml, :json

  def index
    @post_versions = PostArchive.search(PostArchive.build_query(search_params)).paginate(params[:page], :limit => params[:limit], :search_count => params[:search], includes: [:updater, post: [:versions]])
    respond_with(@post_versions) do |format|
      format.xml do
        render :xml => @post_versions.to_xml(:root => "post-versions")
      end
    end
  end

  def search
  end

  def undo
    @post_version = PostArchive.find(params[:id])

    if @post_version.post.visible?
      @post_version.undo!
    end

    respond_with(@post_version) do |format|
      format.js
    end
  end
end
