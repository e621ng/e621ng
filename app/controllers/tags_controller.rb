# frozen_string_literal: true

class TagsController < ApplicationController
  before_action :member_only, only: %i[edit update preview]
  before_action :is_bd_staff_only, only: %i[destroy]
  respond_to :html, :json

  def edit
    @from_wiki = request.referer.try(:include?, "wiki_pages") || false
    @tag = Tag.find(params[:id])
    check_privilege(@tag)
    respond_with(@tag)
  end

  def index
    @tags = Tag.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])

    respond_with(@tags)
  end

  def preview
    # This endpoint needs to be a POST request, because long tag strings will exceed the browser URL length limit.
    @preview = TagsPreview.new(tags: params[:tags])
    render plain: @preview.serializable_hash.to_json, content_type: "application/json"
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

  def destroy
    @tag = Tag.find(params[:id])
    raise User::PrivilegeError unless @tag.deletable_by?(CurrentUser.user)

    errors = []

    # 1. Posts
    count = Post.tag_match("#{@tag.name} status:any", resolve_aliases: false).count_only
    errors.push("Cannot delete tags that are present on posts") if count > 0

    # 2. Aliases
    aliases = TagAlias.where("(antecedent_name = ? OR consequent_name = ?) AND NOT status = ?", @tag.name, @tag.name, "deleted").count
    errors.push("Cannot delete tags with active aliases") if aliases > 0

    # 2. Implications
    implications = TagImplication.where("(antecedent_name = ? OR consequent_name = ?) AND NOT status = ?", @tag.name, @tag.name, "deleted").count
    errors.push("Cannot delete tags with active implications") if implications > 0

    if errors.any?
      redirect_back(fallback_location: tags_path(search: { name_matches: @tag.name }), notice: errors.join("; "))
      return
    end

    @tag.destroy

    respond_with(@tag) do |format|
      format.html do
        redirect_to(tags_path, notice: @tag.valid? ? "Tag destroyed" : @tag.errors.full_messages.join("; "))
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
