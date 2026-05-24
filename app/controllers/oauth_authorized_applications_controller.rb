# frozen_string_literal: true

class OauthAuthorizedApplicationsController < Doorkeeper::AuthorizedApplicationsController
  layout "default"

  skip_before_action :authenticate_resource_owner!
  before_action :logged_in_only
  before_action :reject_api_key_auth
  before_action :reject_bearer_auth

  def index
    apps = Doorkeeper.config.application_model.authorized_for(CurrentUser.user)
    tokens_by_app = Doorkeeper::AccessToken
                    .where(application_id: apps.map(&:id), resource_owner_id: CurrentUser.id, revoked_at: nil)
                    .order(created_at: :asc)
                    .group_by(&:application_id)

    @grants = apps.map do |app|
      tokens = tokens_by_app[app.id] || []
      scopes = tokens.flat_map { |t| t.scopes.to_a }.uniq
      {
        application: app,
        scopes: scopes,
        granted_at: tokens.first&.created_at,
        last_used_at: tokens.map(&:last_used_at).compact.max,
      }
    end
  end

  def destroy
    Doorkeeper.config.application_model.revoke_tokens_and_grants_for(params[:id], CurrentUser.user)
    flash[:notice] = "Access revoked."
    redirect_to(oauth_authorized_applications_path)
  end
end
