# frozen_string_literal: true

class TagsController < ApplicationController
  before_action :member_only, only: %i[edit update preview]
  respond_to :html, :json

  def edit
    @from_wiki = request.referer.try(:include?, "wiki_pages") || false
    @tag = Tag.find(params[:id])
    check_privilege(@tag)
    respond_with(@tag)
  end

  def index
    @tags = Tag.search(search_params).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])

    respond_with(@tags)
  end

  def preview
    @preview = TagsPreview.new(tags: params[:tags])
    respond_to do |format|
      format.json do
        render json: @preview.serializable_hash
      end
    end
  end

  def show
    if params[:id] =~ /\A\d+\z/
      @tag = Tag.find(params[:id])
    else
      @tag = Tag.find_by!(name: params[:id])
    end
    respond_with(@tag)
  end

  def update
    @tag = Tag.find(params[:id])
    check_privilege(@tag)
    @tag.update(tag_params)
    respond_with(@tag) do |format|
      format.html do
        if @tag.from_wiki.to_s.truthy?
          return redirect_to(show_or_new_wiki_pages_path(title: WikiPage.normalize_name(@tag.name)), notice: "Tag updated")
        else
          redirect_to(tags_path(search: { name_matches: @tag.name, hide_empty: "no" }))
        end
      end
    end
  end

  private

  def check_privilege(tag)
    raise User::PrivilegeError unless tag.category_editable_by?(CurrentUser.user)
  end

  def tag_params
    permitted_params = %i[category from_wiki]
    permitted_params << :is_locked if CurrentUser.is_admin?

    params.require(:tag).permit(permitted_params)
  end
end
