# frozen_string_literal: true

module Staff
  class WikiRefsController < ApplicationController
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

    def bulk_create
      @staff_wiki = StaffWiki.find(params[:wiki_id])
      result = StaffWikiRefParser.parse(params[:urls])

      created = 0
      skipped = 0
      result.references.each do |attributes| # rubocop:disable Rails/FindEach -- plain Array, not a relation
        ref = @staff_wiki.references.create(attributes)
        if ref.errors.none?
          created += 1
        else
          skipped += 1
        end
      end

      parts = ["Added #{created} #{'reference'.pluralize(created)}"]
      parts << "#{skipped} already existed" if skipped > 0
      if result.failures.any?
        inputs = result.failures.pluck(:input).join(", ")
        parts << "#{result.failures.size} could not be parsed: #{inputs}"
      end

      message = parts.join("; ")
      if created > 0
        flash[:notice] = message
      else
        flash[:alert] = message
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
