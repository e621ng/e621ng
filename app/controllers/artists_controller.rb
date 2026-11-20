# frozen_string_literal: true

class ArtistsController < ApplicationController
  include ConditionalSearchCount

  respond_to :html, :json
  before_action :member_only, except: %i[index show show_or_new]
  before_action :admin_only, only: %i[destroy]
  before_action :load_artist, only: %i[edit update destroy revert]

  def index
    # Only enable COUNT for searches that actually narrow results to avoid expensive queries
    search_params_for_count = search_count_params(
      narrowing: %i[id name group_name any_other_name_like any_name_matches
                    any_name_or_url_matches url_matches creator_name creator_id
                    linked_user_id linked_user_name],
      falsy: %i[has_tag],
      truthy: %i[is_linked],
    )

    @artists = Artist.search(search_params).paginate(params[:page], limit: params[:limit], search_count: search_params_for_count)
    respond_with(@artists) do |format|
      format.json do
        # Eager load URLs only for JSON response to avoid N+1 queries
        ActiveRecord::Associations::Preloader.new(records: @artists, associations: :urls).call
        render json: @artists.to_json(include: [:urls])
        expires_in params[:expiry].to_i.days if params[:expiry]
      end
    end
  end

  def show
    respond_to do |format|
      format.html do
        # An id names one specific entry, so it never follows aliases.
        if params[:id] =~ /\A\d+\z/
          redirect_to(short_artist_path(Artist.find(params[:id]).name, redirect: "no"), status: 301)
        else
          redirect_to(short_artist_path(params[:id]), status: 301)
        end
      end
      format.json do
        load_artist
        render(json: @artist.to_json(methods: [:domains], include: [:urls]))
      end
    end
  end

  def new
    @artist = Artist.new(artist_params)
    respond_with(@artist)
  end

  def edit
    ensure_can_edit(CurrentUser.user)
    respond_with(@artist)
  end

  def create
    @artist = Artist.create(artist_params)
    respond_with(@artist, location: -> { short_artist_path(@artist.name, redirect: "no") })
  end

  def update
    ensure_can_edit(CurrentUser.user)
    @artist.update(artist_params)
    flash[:notice] = @artist.valid? ? "Artist updated" : @artist.errors.full_messages.join("; ")
    respond_with(@artist, location: -> { short_artist_path(@artist.name, redirect: "no") })
  end

  def destroy
    raise User::PrivilegeError unless @artist.deletable_by?(CurrentUser.user)
    @artist.destroy
    respond_with(@artist) do |format|
      format.html do
        redirect_to(artists_path, notice: @artist.valid? ? "Artist deleted" : @artist.errors.full_messages.join("; "))
      end
    end
  end

  def revert
    ensure_can_edit(CurrentUser.user)
    @version = @artist.versions.find(params[:version_id])
    @artist.revert_to!(@version)
    respond_with(@artist, location: -> { short_artist_path(@artist.name, redirect: "no") })
  end

  def show_or_new
    name = Artist.normalize_name(params[:name].to_s)
    raise ActiveRecord::RecordNotFound if name.blank?
    respond_to do |format|
      format.html { redirect_to(short_artist_path(name), status: 301) }
      format.json { render(json: Artist.find_by!(name: name).to_json(methods: [:domains], include: [:urls])) }
    end
  end

  private

  def load_artist
    if params[:id] =~ /\A\d+\z/
      @artist = Artist.find(params[:id])
    else
      @artist = Artist.named(params[:id])
      raise ActiveRecord::RecordNotFound if @artist.blank?
    end
  end

  def search_params
    sp = params.fetch(:search, {})
    sp[:name] = params[:name] if params[:name]
    sp.permit!
  end

  def ensure_can_edit(user)
    raise(User::PrivilegeError, "Artist is locked.") unless @artist.editable_by?(user)
  end

  def artist_params
    permitted_params = %i[name other_names other_names_string group_name url_string notes]
    permitted_params += %i[linked_user_id is_locked] if CurrentUser.is_staff?

    params.fetch(:artist, {}).permit(permitted_params)
  end
end
