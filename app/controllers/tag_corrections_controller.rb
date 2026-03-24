# frozen_string_literal: true

class TagCorrectionsController < ApplicationController
  respond_to :html, :json
  before_action :janitor_only, only: %i[new create]

  def show
    @correction = TagCorrection.new(params[:tag_id])
    respond_with(@correction)
  end

  def new
    @from_wiki = request.referer.try(:include?, "wiki_pages") || false
    @correction = TagCorrection.new(params[:tag_id])

    if CurrentUser.is_bd_staff?
      @tag = Tag.find(params[:tag_id])

      @true_count = Post.tag_match("#{@tag.name} status:any", resolve_aliases: false).count_only
      @aliases = TagAlias.where("(antecedent_name = ? OR consequent_name = ?) AND NOT status = ?", @tag.name, @tag.name, "deleted").count
      @implications = TagImplication.where("(antecedent_name = ? OR consequent_name = ?) AND NOT status = ?", @tag.name, @tag.name, "deleted").count

      # If a tag is aliased away but still has posts, it means one of two things:
      # 1. Alias is still being processed, tag counts have not been updated yet
      # 2. Alias is stuck, tag counts will never be updated
      @is_aliased_away = TagAlias.where(antecedent_name: @correction.tag.name, status: %w[active processing queued]).exists?
      if @is_aliased_away && @true_count != 0
        @true_post_ids = @true_count > 20 ? "> 20" : Post.tag_match("#{@tag.name} status:any", resolve_aliases: false).pluck(:id).join(", ")
      end

      @destroyable = @true_count == 0 && @aliases == 0 && @implications == 0
    end

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
