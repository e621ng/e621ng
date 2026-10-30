# frozen_string_literal: true

class SavedSearchesController < ApplicationController
  respond_to :html, :json
  before_action :member_only

  def index
    # The subscription anchor is created lazily, so pin it above older searches
    @saved_searches = CurrentUser.user.saved_searches.reorder(is_subscription: :desc, id: :asc)
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
    redirect_to tag_subscriptions_path if @saved_search.is_subscription?
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
    return refuse_subscription_edit if @saved_search.is_subscription?
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

  # Advances the watermark (tracked searches only) and lands on the only-new-posts view when
  # the cached badge count says there are any; the index refreshes that count right before
  # rendering these links. The search: metatag itself is read-only.
  def visit
    @saved_search = CurrentUser.user.saved_searches.find(params[:id])
    redirect_to posts_path(tags: @saved_search.visit_tags)
  end

  def mark_all_seen
    SavedSearch.mark_all_seen!(CurrentUser.user)
    respond_with(nil, location: saved_searches_path) do |format|
      format.html { redirect_to saved_searches_path, notice: "All saved searches marked as seen" }
      format.json { head 204 }
    end
  end

  # Cache-only re-read for the nav badge; never queries OpenSearch or enqueues.
  def badge
    respond_to do |format|
      format.json { render json: SavedSearch.badge_summary(CurrentUser.user) }
    end
  end

  private

  # The subscription anchor's content is managed through tag_subscriptions only.
  def refuse_subscription_edit
    respond_to do |format|
      format.html { redirect_to tag_subscriptions_path }
      format.json { render_expected_error(403, "Subscriptions are managed through tag subscriptions") }
    end
  end

  def permitted_params
    params.fetch(:saved_search, {}).permit(%i[query name is_tracked])
  end
end
