class HelpController < ApplicationController
  respond_to :html, :json, :xml
  helper :wiki_pages
  before_action :admin_only, only: [:new, :create, :edit,
                                    :update, :destroy]

  def show
    if params[:id] =~ /\A\d+\Z/
      @help = HelpPage.find(params[:id])
    else
      @help = HelpPage.find_by_name(params[:id])
    end
    return redirect_to help_pages_path unless @help.present?
    @wiki_page = WikiPage.find_by_title(@help.wiki_page)
    @related = @help.related.split(', ')
    respond_with(@help)
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
      ModAction.log("User ##{CurrentUser.id} created help page #{@help.name}", :create_help_page)
    end
    respond_with(@help)
  end

  def update
    @help = HelpPage.find(params[:id])
    @help.update(help_params)
    if @help.valid?
      ModAction.log("User ##{CurrentUser.id} edited help entry #{@help.name}")
      flash[:notice] = "Help entry updated"
    end
    respond_with(@help)
  end

  def destroy
    @help = HelpPage.find(params[:id])
    @help.destroy
    ModAction.log("User ##{CurrentUser.id} destroyed help page #{@help.title}", :delete_help_page)
    respond_with(@help)
  end

  private

  def help_params
    params.require(:help_page).permit(%i[name wiki_page related title])
  end
end
