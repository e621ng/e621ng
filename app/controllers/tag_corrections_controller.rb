# frozen_string_literal: true

class TagCorrectionsController < ApplicationController
  respond_to :html, :json
  before_action :janitor_only, only: [:new, :create]

  def new
    @from_wiki = request.referer.try(:include?, "wiki_pages") || false
    @correction = TagCorrection.new(params[:tag_id])

    if CurrentUser.is_bd_staff?
      @tag = Tag.find(params[:tag_id])

      @true_count = Post.tag_match("#{@tag.name} status:any", resolve_aliases: false).count_only
      @aliases = TagAlias.where("(antecedent_name = ? OR consequent_name = ?) AND NOT status = ?", @tag.name, @tag.name, "deleted").count
      @implications = TagImplication.where("(antecedent_name = ? OR consequent_name = ?) AND NOT status = ?", @tag.name, @tag.name, "deleted").count

      @destroyable = @true_count == 0 && @aliases == 0 && @implications == 0
    end

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
