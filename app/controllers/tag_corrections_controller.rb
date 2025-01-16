# frozen_string_literal: true

class TagCorrectionsController < ApplicationController
  respond_to :html, :json
  before_action :janitor_only, only: [:new, :create]

  def new
    @from_wiki = request.referer.try(:include?, "wiki_pages") || false
    @correction = TagCorrection.new(params[:tag_id])
    respond_with(@correction)
  end

  def show
    @correction = TagCorrection.new(params[:tag_id])
    respond_with(@correction)
  end

  def create
    @correction = TagCorrection.new(params[:tag_id])

    if params[:commit] == "Fix"
      @correction.fix!
      if params[:from_wiki].to_s.truthy?
        return redirect_to(show_or_new_wiki_pages_path(title: WikiPage.normalize_name(@correction.tag.name)), notice: "Tag will be fixed in a few seconds")
      end
      redirect_to(tags_path(search: { name_matches: @correction.tag.name, hide_empty: "no"}), notice: "Tag will be fixed in a few seconds")
    else
      redirect_to(tags_path(search: { name_matches: @correction.tag.name }))
    end
  end
end
