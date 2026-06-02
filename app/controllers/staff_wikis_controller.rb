# frozen_string_literal: true

class StaffWikisController < ApplicationController
  respond_to :html, :json
  before_action :janitor_only
  before_action :admin_only, only: [:destroy]

  def index
    @staff_wikis = StaffWiki.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
    respond_with(@staff_wikis)
  end

  def show
    @staff_wiki = StaffWiki.find(params[:id])
    @involved_users = @staff_wiki.versions.map(&:updater).uniq
    respond_with(@staff_wiki)
  end

  def show_or_new
    @staff_wiki = StaffWiki.titled(params[:title].to_s)
    if @staff_wiki.present?
      @involved_users = @staff_wiki.versions.map(&:updater).uniq
      redirect_to @staff_wiki
    else
      @staff_wiki = StaffWiki.new(title: StaffWiki.normalize_name(params[:title].to_s))
      respond_with(@staff_wiki)
    end
  end

  def search
  end

  def new
    @staff_wiki = StaffWiki.new(staff_wiki_params)
    respond_with(@staff_wiki)
  end

  def edit
    @staff_wiki = StaffWiki.find(params[:id])
    respond_with(@staff_wiki)
  end

  def create
    @staff_wiki = StaffWiki.create(staff_wiki_params)
    respond_with(@staff_wiki)
  end

  def update
    @staff_wiki = StaffWiki.find(params[:id])
    @staff_wiki.update(staff_wiki_params)
    respond_with(@staff_wiki)
  end

  def destroy
    @staff_wiki = StaffWiki.find(params[:id])
    @staff_wiki.destroy
    flash[:notice] = @staff_wiki.errors.none? ? "Page destroyed" : @staff_wiki.errors.full_messages.join("; ")
    respond_with(@staff_wiki)
  end

  def revert
    @staff_wiki = StaffWiki.find(params[:id])
    @version = @staff_wiki.versions.find(params[:version_id])
    @staff_wiki.revert_to!(@version)
    flash[:notice] = "Page was reverted"
    respond_with(@staff_wiki)
  end

  private

  def staff_wiki_params
    params.fetch(:staff_wiki, {}).permit(:title, :body, :edit_reason)
  end

  def search_params
    permit_search_params %i[title body_matches creator_id creator_name order]
  end
end
