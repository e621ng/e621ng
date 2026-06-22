# frozen_string_literal: true

module Staff
  class StaffWikisController < ApplicationController
    respond_to :html, :json
    before_action :staff_only
    before_action :admin_only, only: [:destroy]

    def index
      @staff_wikis = StaffWiki.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
      respond_with(@staff_wikis)
    end

    def show
      @staff_wiki = StaffWiki.includes(:references, :claimant, versions: [:updater]).find(params[:id])
      @involved_users = @staff_wiki.versions.map(&:updater).uniq

      user_ref_ids   = @staff_wiki.references.where(related_type: "User").select(:related_id)
      artist_ref_ids = @staff_wiki.references.where(related_type: "Artist").select(:related_id)

      @related_pages = StaffWiki
                       .where.not(id: @staff_wiki.id)
                       .where(
                         id: StaffWikiRef
                              .where(related_type: "User", related_id: user_ref_ids)
                              .or(StaffWikiRef.where(related_type: "Artist", related_id: artist_ref_ids))
                              .select(:staff_wiki_id),
                       )

      respond_with(@staff_wiki)
    end

    def new
      @staff_wiki = StaffWiki.new(staff_wiki_params(:create))
      respond_with(@staff_wiki)
    end

    def edit
      @staff_wiki = StaffWiki.find(params[:id])
      respond_with(@staff_wiki)
    end

    def create
      @staff_wiki = StaffWiki.create(staff_wiki_params(:create))
      respond_with(@staff_wiki)
    end

    def update
      @staff_wiki = StaffWiki.find(params[:id])
      @staff_wiki.update(staff_wiki_params(:update))
      respond_with(@staff_wiki)
    end

    def destroy
      @staff_wiki = StaffWiki.find(params[:id])
      @staff_wiki.destroy
      flash[:notice] = @staff_wiki.errors.none? ? "Page destroyed" : @staff_wiki.errors.full_messages.join("; ")
      respond_with(@staff_wiki)
    end

    def revert
      @staff_wiki = StaffWiki.find(params[:id])
      @version = @staff_wiki.versions.find(params[:version_id])
      @staff_wiki.revert_to!(@version)
      flash[:notice] = "Page was reverted"
      respond_with(@staff_wiki)
    end

    def claim
      @staff_wiki = StaffWiki.find(params[:id])
      @staff_wiki.update(claimant_id: CurrentUser.id)
      unless @staff_wiki.errors.none?
        flash[:alert] = @staff_wiki.errors.full_messages.join("; ")
      end

      respond_with(@staff_wiki)
    end

    def unclaim
      @staff_wiki = StaffWiki.find(params[:id])
      @staff_wiki.update(claimant_id: nil)
      unless @staff_wiki.errors.none?
        flash[:alert] = @staff_wiki.errors.full_messages.join("; ")
      end

      respond_with(@staff_wiki)
    end

    private

    def staff_wiki_params(context)
      permitted_params = %i[title body edit_reason]
      permitted_params += %i[related_type related_id] if context == :create
      params.fetch(:staff_wiki, {}).permit(permitted_params)
    end

    def search_params
      permit_search_params %i[title body_matches creator_id creator_name editor_id order]
    end
  end
end
