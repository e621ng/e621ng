# frozen_string_literal: true

class SavedSearchesController < ApplicationController
  respond_to :html, :json
  before_action :member_only

  def index
    @saved_searches = CurrentUser.user.saved_searches
    # The user explicitly asked: compute fresh counts (cache updated as a side effect)
    @counts = SavedSearch.refresh_badge_counts!(CurrentUser.user)
    respond_with(@saved_searches) do |format|
      format.json { render json: SavedSearchBlueprint.render(@saved_searches, counts: @counts) }
    end
  end

  def show
    @saved_search = CurrentUser.user.saved_searches.find(params[:id])
    respond_with(@saved_search) do |format|
      format.html { redirect_to saved_searches_path }
      format.json { render json: SavedSearchBlueprint.render(@saved_search, counts: SavedSearch.badge_counts(CurrentUser.user)) }
    end
  end

  def new
    @saved_search = SavedSearch.new(permitted_params)
  end

  def edit
    @saved_search = CurrentUser.user.saved_searches.find(params[:id])
  end

  def create
    @saved_search = CurrentUser.user.saved_searches.create(permitted_params)
    # Failure re-renders the form, which displays the errors itself
    flash[:notice] = "Search saved" if @saved_search.valid?
    respond_with(@saved_search, location: saved_searches_path) do |format|
      format.json do
        if @saved_search.valid?
          render json: SavedSearchBlueprint.render(@saved_search)
        else
          render_expected_error(422, @saved_search.errors.full_messages.join("; "))
        end
      end
    end
  end

  def update
    @saved_search = CurrentUser.user.saved_searches.find(params[:id])
    @saved_search.update(permitted_params)
    # Failure re-renders the form, which displays the errors itself
    flash[:notice] = "Search updated" if @saved_search.valid?
    respond_with(@saved_search, location: saved_searches_path) do |format|
      format.json do
        if @saved_search.valid?
          render json: SavedSearchBlueprint.render(@saved_search)
        else
          render_expected_error(422, @saved_search.errors.full_messages.join("; "))
        end
      end
    end
  end

  def destroy
    @saved_search = CurrentUser.user.saved_searches.find(params[:id])
    @saved_search.destroy
    respond_with(@saved_search, location: saved_searches_path)
  end

  # Advances the watermark (tracked searches only) and lands on the only-new-posts view.
  # This is the sole watermark-advancing search path; the search: metatag itself is read-only.
  def visit
    @saved_search = CurrentUser.user.saved_searches.find(params[:id])
    old_watermark = @saved_search.mark_seen!
    tags = "search:#{@saved_search.name || @saved_search.id}"
    tags += " id:>#{old_watermark}" if old_watermark
    redirect_to posts_path(tags: tags)
  end

  def mark_all_seen
    SavedSearch.mark_all_seen!(CurrentUser.user)
    respond_with(nil, location: saved_searches_path) do |format|
      format.html { redirect_to saved_searches_path, notice: "All saved searches marked as seen" }
      format.json { head 204 }
    end
  end

  private

  def permitted_params
    params.fetch(:saved_search, {}).permit(%i[query name is_tracked])
  end
end
