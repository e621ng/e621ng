# frozen_string_literal: true

module Staff
  class StaffWikiRefsController < ApplicationController
    before_action :staff_only

    def create
      @staff_wiki = StaffWiki.find(params[:wiki_id])
      @ref = @staff_wiki.references.create(staff_wiki_ref_params)
      if @ref.errors.none?
        flash[:notice] = "Reference added"
      else
        flash[:alert] = @ref.errors.full_messages.join("; ")
      end
      redirect_to @staff_wiki
    end

    def destroy
      @staff_wiki = StaffWiki.find(params[:wiki_id])
      @ref = @staff_wiki.references.find(params[:id])
      @ref.destroy
      flash[:notice] = "Reference removed"
      redirect_to @staff_wiki
    end

    private

    def staff_wiki_ref_params
      params.require(:staff_wiki_ref).permit(:related_type, :related_id)
    end
  end
end
