# frozen_string_literal: true

module Staff
  class WikiVersionsController < ApplicationController
    respond_to :html, :json
    before_action :staff_only

    def index
      @staff_wiki_versions = StaffWikiVersion.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
      respond_with(@staff_wiki_versions)
    end

    def show
      @staff_wiki_version = StaffWikiVersion.find(params[:id])
      respond_with(@staff_wiki_version)
    end

    def diff
      if params[:thispage].blank? || params[:otherpage].blank?
        redirect_back fallback_location: staff_wikis_path, notice: "You must select two versions to diff"
        return
      end

      @thispage  = StaffWikiVersion.find(ParseValue.safe_id(params[:thispage].to_s))
      @otherpage = StaffWikiVersion.find(ParseValue.safe_id(params[:otherpage].to_s))
    end

    private

    def search_params
      permitted = %i[updater_id updater_name staff_wiki_id title body]
      permitted += %i[ip_addr] if CurrentUser.is_admin?
      permit_search_params permitted
    end
  end
end
