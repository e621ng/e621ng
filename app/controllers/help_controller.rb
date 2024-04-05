# frozen_string_literal: true

class HelpController < ApplicationController
  respond_to :html, :json
  helper :wiki_pages
  before_action :admin_only, only: [:new, :create, :edit,
                                    :update, :destroy]

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
      format.json do
        raise ActiveRecord::RecordNotFound if @help.blank?
        render json: @help
      end
    end
  end

  def index
    @help_pages = HelpPage.help_index
    respond_with(@help_pages)
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
    if @help.valid?
      flash[:notice] = 'Help page created'
      ModAction.log(:help_create, {name: @help.name, wiki_page: @help.wiki_page})
    end
    respond_with(@help)
  end

  def update
    @help = HelpPage.find(params[:id])
    @help.update(help_params)
    if @help.valid?
      flash[:notice] = "Help entry updated"
      ModAction.log(:help_update,{name: @help.name, wiki_page: @help.wiki_page})
    end
    respond_with(@help)
  end

  def destroy
    @help = HelpPage.find(params[:id])
    @help.destroy
    ModAction.log(:help_delete, {name: @help.name, wiki_page: @help.wiki_page})
    respond_with(@help)
  end

  private

  def help_params
    params.require(:help_page).permit(%i[name wiki_page related title])
  end
end
