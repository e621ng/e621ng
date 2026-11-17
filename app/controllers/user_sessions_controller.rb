# frozen_string_literal: true

# The browsers a user is logged in to (doc 42). Cookie logins only: an API key
# or bearer token must not be able to list or end them.
class UserSessionsController < ApplicationController
  before_action :logged_in_only
  before_action :reject_api_key_auth
  before_action :reject_bearer_auth
  before_action :requires_reauthentication
  respond_to :html

  def index
    @current_session = CurrentUser.user_session
    @user_sessions = CurrentUser.user.user_sessions.listed.order(last_seen_at: :desc).to_a
    @networks = AsnRange.lookup(@user_sessions.filter_map(&:last_ip))
  end

  def destroy
    user_session = CurrentUser.user.user_sessions.active.find(params.expect(:id))
    if user_session.id == CurrentUser.user_session&.id
      return render_expected_error(422, "Log out to end the current session")
    end

    user_session.revoke!("user")
    redirect_to(user_sessions_path, notice: "Session revoked")
  end

  def revoke_others
    count = UserSession.revoke_all!(CurrentUser.user, reason: "others", except: CurrentUser.user_session)
    redirect_to(user_sessions_path, notice: "Logged out #{count} other #{'session'.pluralize(count)}")
  end
end
