# frozen_string_literal: true

class WikiPageVersionsController < ApplicationController
  respond_to :html, :json

  def index
    @wiki_page_versions = WikiPageVersion.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
    respond_with(@wiki_page_versions)
  end

  def show
    @wiki_page_version = WikiPageVersion.find(params[:id])
    respond_with(@wiki_page_version)
  end

  def diff
    if params[:thispage].blank? || params[:otherpage].blank?
      redirect_back fallback_location: wiki_pages_path, notice: "You must select two versions to diff"
      return
    end

    @thispage = WikiPageVersion.find(params[:thispage])
    @otherpage = WikiPageVersion.find(params[:otherpage])
  end

  private

  def search_params
    permitted_params = %i[updater_id updater_name wiki_page_id title body is_locked is_deleted]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
