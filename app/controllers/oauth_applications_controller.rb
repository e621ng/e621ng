# frozen_string_literal: true

class OauthApplicationsController < Doorkeeper::ApplicationsController
  layout "default"

  skip_before_action :authenticate_admin!
  before_action :staff_only
  before_action :reject_api_key_auth
  before_action :reject_bearer_auth
  before_action :requires_reauthentication
  before_action :set_visible_application, only: %i[show]
  before_action :set_owned_application, only: %i[edit update destroy regenerate_secret]

  helper_method :search_params

  def index
    @applications = application_model.search(search_params).ordered_by(:created_at).paginate(params[:page], limit: params[:limit])
  end

  def mine
    @applications = owned_applications.ordered_by(:created_at)
  end

  def show
    redirect_to(edit_oauth_application_url(@application)) if @application.owner_id == CurrentUser.user.id
  end

  def create
    @application = owned_applications.new(application_params)
    @application.owner = CurrentUser.user
    if @application.save
      flash[:notice] = "Application created"
      redirect_to(edit_oauth_application_url(@application))
    else
      render(:new)
    end
  end

  def update
    if @application.update(application_params)
      flash[:notice] = "Application saved"
      redirect_to(edit_oauth_application_url(@application))
    else
      render(:edit)
    end
  end

  def destroy
    @application.destroy
    flash[:notice] = "Application deleted"
    redirect_to(mine_oauth_applications_url)
  end

  def regenerate_secret
    @application.renew_secret
    @application.save!
    flash[:notice] = "Client secret regenerated. Any clients using the old secret must be updated."
    redirect_to(oauth_application_url(@application))
  end

  private

  def application_model
    Doorkeeper.config.application_model
  end

  def owned_applications
    application_model.where(owner: CurrentUser.user)
  end

  def set_visible_application
    @application = application_model.find(params[:id])
  end

  def set_owned_application
    @application = owned_applications.find(params[:id])
  end

  def search_params
    params.fetch(:search, {}).permit(:name, :owner_name)
  end

  def application_params
    allowed_keys = %i[name confidential description homepage_url]
    allowed_keys << :minimum_user_level if CurrentUser.user.is_janitor?

    permitted = params.require(:doorkeeper_application).permit(
      *allowed_keys, redirect_uris: [], scopes: []
    )
    permitted[:redirect_uri] = Array(permitted.delete(:redirect_uris)).map(&:strip).compact_blank.join("\n")
    permitted[:scopes] = Array(permitted[:scopes]).compact_blank.join(" ")
    permitted[:minimum_user_level] = permitted[:minimum_user_level].to_i if permitted[:minimum_user_level].present?
    permitted
  end
end
