# frozen_string_literal: true

class HelpController < ApplicationController
  respond_to :html, :json
  helper :wiki_pages
  before_action :admin_only, except: %i[index show]

  def show
    if params[:id] =~ /\A\d+\Z/
      @help = HelpPage.find(params[:id])
    else
      @help = HelpPage.find_by(name: params[:id])
    end
    respond_with(@help) do |format|
      format.html do
        if @help.blank?
          redirect_to help_pages_path
        end
      end
    end
  end

  def index
    @help_pages = HelpPage.help_index
    respond_with(@help_pages) do |format|
      format.json { render json: @help_pages.to_json }
    end
  end

  def new
    @help = HelpPage.new
    respond_with(@help)
  end

  def edit
    @help = HelpPage.find(params[:id])
    respond_with(@help)
  end

  def create
    @help = HelpPage.create(help_params)
    flash[:notice] = "Help page created" if @help.valid?
    respond_with(@help)
  end

  def update
    @help = HelpPage.find(params[:id])
    @help.update(help_params)
    flash[:notice] = "Help entry updated" if @help.valid?
    respond_with(@help)
  end

  def destroy
    @help = HelpPage.find(params[:id])
    @help.destroy
    respond_with(@help)
  end

  private

  def help_params
    params.require(:help_page).permit(%i[name wiki_page related title])
  end
end
