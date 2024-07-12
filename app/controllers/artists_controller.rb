# frozen_string_literal: true

class ArtistsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, :except => [:index, :show, :show_or_new]
  before_action :janitor_only, :only => [:destroy]
  before_action :load_artist, :only => [:edit, :update, :destroy]

  def new
    @artist = Artist.new(artist_params(:new))
    respond_with(@artist)
  end

  def edit
    respond_with(@artist)
  end

  def index
    @artists = Artist.includes(:urls).search(search_params).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@artists) do |format|
      format.json do
        render :json => @artists.to_json(:include => [:urls])
        expires_in params[:expiry].to_i.days if params[:expiry]
      end
    end
  end

  def show
    if params[:id] =~ /\A\d+\z/
      @artist = Artist.find(params[:id])
    else
      @artist = Artist.find_by(name: Artist.normalize_name(params[:id]))
      unless @artist
        respond_to do |format|
          format.html do
            redirect_to(show_or_new_artists_path(name: params[:id]))
          end
          format.json do
            raise ActiveRecord::RecordNotFound
          end
        end
        return
      end
    end
    @post_set = PostSets::Post.new(@artist.name, 1, limit: 10)
    respond_with(@artist, methods: [:domains], include: [:urls])
  end

  def create
    @artist = Artist.create(artist_params)
    respond_with(@artist)
  end

  def update
    ensure_can_edit(CurrentUser.user)
    @artist.update(artist_params)
    flash[:notice] = @artist.valid? ? "Artist updated" : @artist.errors.full_messages.join("; ")
    respond_with(@artist)
  end

  def destroy
    unless @artist.deletable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
    @artist.update_attribute(:is_active, false)
    respond_with(@artist) do |format|
      format.html do
        redirect_to(artist_path(@artist), notice: "Artist deleted")
      end
    end
  end

  def revert
    @artist = Artist.find(params[:id])
    ensure_can_edit(CurrentUser.user)
    @version = @artist.versions.find(params[:version_id])
    @artist.revert_to!(@version)
    respond_with(@artist)
  end

  def show_or_new
    @artist = Artist.find_by(name: params[:name])
    if @artist
      redirect_to artist_path(@artist)
    else
      @artist = Artist.new(name: params[:name] || "")
      @post_set = PostSets::Post.new(@artist.name, 1, limit: 10)
      respond_with(@artist)
    end
  end

private

  def load_artist
    @artist = Artist.find(params[:id])
  end

  def search_params
    sp = params.fetch(:search, {})
    sp[:name] = params[:name] if params[:name]
    sp.permit!
  end

  def ensure_can_edit(user)
    return if user.is_janitor?
    raise User::PrivilegeError if @artist.is_locked?
    raise User::PrivilegeError if !@artist.is_active?
  end

  def artist_params(context = nil)
    permitted_params = %i[name other_names other_names_string group_name url_string notes]
    permitted_params += [:is_active, :linked_user_id, :is_locked] if CurrentUser.is_janitor?
    permitted_params << :source if context == :new

    params.fetch(:artist, {}).permit(permitted_params)
  end
end
