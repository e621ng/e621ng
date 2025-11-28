# frozen_string_literal: true

class ApplicationController < ActionController::Base
  class APIThrottled < Exception; end
  class FeatureUnavailable < StandardError; end

  skip_forgery_protection if: -> { SessionLoader.new(request).has_api_authentication? || request.options? }
  before_action :reset_current_user
  before_action :sanitize_params
  before_action :set_current_user
  before_action :normalize_search
  before_action :api_check
  before_action :enable_cors
  before_action :check_valid_username
  after_action :reset_current_user
  layout "default"

  include TitleHelper
  include DeferredPosts
  include RenderPartialSafely
  helper_method :deferred_post_ids, :deferred_posts

  rescue_from Exception, :with => :rescue_exception
  rescue_from User::PrivilegeError, :with => :access_denied
  rescue_from ActionController::UnpermittedParameters, :with => :access_denied

  # This is raised on requests to `/blah.js`. Rails has already rendered StaticController#not_found
  # here, so calling `rescue_exception` would cause a double render error.
  rescue_from ActionController::InvalidCrossOriginRequest, with: -> {}

  def enable_cors
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, User-Agent"
    response.headers["Access-Control-Allow-Methods"] = "POST, PUT, PATCH, DELETE, GET, HEAD, OPTIONS"
  end

  def check_valid_username
    return if params[:controller] == "user_name_change_requests"

    if request.format.html? && CurrentUser.user.name_error
      redirect_to new_user_name_change_request_path
    end
  end

  protected

  def sanitize_params
    sanitize_hash = ->(hash) do
      hash.each do |key, value|
        hash[key] = case value
                    when String
                      # Remove invalid UTF-8 sequences and null bytes
                      value.scrub("").delete("\u0000")
                    when Hash, ActionController::Parameters
                      sanitize_hash.call(value)
                    when Array
                      value.map { |v| v.is_a?(String) ? v.scrub("").delete("\u0000") : v }
                    else
                      value
                    end
      end
    end

    sanitize_hash.call(params)
  end

  def api_check
    if !CurrentUser.is_anonymous? && !request.get? && !request.head?
      throttled = CurrentUser.user.token_bucket.throttled?
      headers["X-Api-Limit"] = CurrentUser.user.token_bucket.cached_count.to_s

      if throttled
        raise APIThrottled.new
        return false
      end
    end

    true
  end

  def rescue_exception(exception)
    @exception = exception

    # If InvalidAuthenticityToken was raised, CurrentUser isn't set so we have to do it here manually.
    CurrentUser.user ||= User.anonymous

    case exception
    when ProcessingError
      render_expected_error(400, exception)
    when APIThrottled
      render_expected_error(429, "Throttled: Too many requests")
    when ActiveRecord::QueryCanceled
      render_error_page(500, exception, message: "The database timed out running your query.")
    when ActionController::BadRequest, PostVersion::UndoError
      render_error_page(400, exception)
    when SessionLoader::AuthenticationFailure
      session.delete(:user_id)
      cookies.delete :remember
      render_expected_error(401, exception.message)
    when ActionController::InvalidAuthenticityToken
      render_expected_error(403, "ActionController::InvalidAuthenticityToken. Did you properly authorize your request?")
    when ActiveRecord::RecordNotFound
      render_404
    when ActionController::RoutingError
      render_error_page(405, exception)
    when ActionController::UnknownFormat, ActionView::MissingTemplate
      render_unsupported_format
    when Danbooru::Paginator::PaginationError
      render_expected_error(410, exception.message)
    when TagQuery::CountExceededError, TagQuery::DepthExceededError, TagQuery::InvalidTagError
      render_expected_error(422, exception.message)
    when FeatureUnavailable
      render_expected_error(400, "This feature isn't available")
    when PG::ConnectionBad
      render_error_page(503, exception, message: "The database is unavailable. Try again later.")
    when ActionController::ParameterMissing
      render_expected_error(400, exception.message)
    when BCrypt::Errors::InvalidHash
      render_expected_error(400, "You must reset your password.")
    else
      render_error_page(500, exception)
    end
  end

  def render_404
    respond_to do |fmt|
      fmt.html do
        render "static/404", formats: [:html, :atom], status: 404
      end
      fmt.json do
        render json: { success: false, reason: "not found" }, status: 404
      end
      fmt.any do
        render_unsupported_format
      end
    end
  end

  def render_unsupported_format
    render_expected_error(406, "#{request.format} is not a supported format for this page", format: :html)
  end

  def render_expected_error(status, message, format: request.format.symbol)
    format = :html unless format.in?(%i[html json atom])
    @message = message
    render "static/error", status: status, formats: format
  end

  def render_error_page(status, exception, message: exception.message, format: request.format.symbol)
    @exception = exception
    @expected = status < 500
    @message = message.encode("utf-8", invalid: :replace, undef: :replace )
    @backtrace = Rails.backtrace_cleaner.clean(@exception.backtrace)
    format = :html unless format.in?(%i[html json atom])

    if !CurrentUser.user.is_janitor? && message == exception.message
      @message = "An unexpected error occurred."
    end

    DanbooruLogger.log(@exception, expected: @expected)
    log = ExceptionLog.add(exception, CurrentUser.id, request) if !@expected
    @log_code = log&.code
    render "static/error", status: status, formats: format
  end

  def access_denied(exception = nil)
    previous_url = params[:url] || request.fullpath
    @message = "Access Denied: #{exception}" if exception.is_a?(String)
    @message ||= exception&.message || "Access Denied"

    respond_to do |fmt|
      fmt.html do
        if CurrentUser.is_anonymous?
          if request.get?
            redirect_to new_session_path(:url => previous_url), notice: @message
          else
            redirect_to new_session_path, notice: @message
          end
        else
          render :template => "static/access_denied", :status => 403
        end
      end
      fmt.json do
        render :json => {:success => false, reason: @message}.to_json, :status => 403
      end
    end
  end

  def set_current_user
    SessionLoader.new(request).load
    session.send(:load!) unless session.send(:loaded?)
  end

  def reset_current_user
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
    CurrentUser.safe_mode = Danbooru.config.safe_mode?
  end

  def requires_reauthentication
    return redirect_to(new_session_path(url: request.fullpath)) if CurrentUser.user.is_anonymous?
    last_authenticated_at = session[:last_authenticated_at]
    if last_authenticated_at.blank? || Time.zone.parse(last_authenticated_at) < 1.hour.ago
      redirect_to(confirm_password_session_path(url: request.fullpath))
    end
  end

  def user_access_check(method)
    if !CurrentUser.user.send(method) || CurrentUser.user.is_banned? || IpBan.is_banned?(CurrentUser.ip_addr)
      access_denied
    end
  end

  User::Roles.each do |role|
    define_method("#{role}_only") do
      user_access_check("is_#{role}?")
    end
  end

  %i[is_bd_staff can_view_staff_notes can_handle_takedowns can_edit_avoid_posting_entries].each do |role|
    define_method("#{role}_only") do
      user_access_check("#{role}?")
    end
  end

  def logged_in_only
    if CurrentUser.is_anonymous?
      access_denied("Must be logged in")
    end
  end

  # Remove blank `search` params from the url.
  #
  # /tags?search[name]=touhou&search[category]=&search[order]=
  # => /tags?search[name]=touhou
  def normalize_search
    return unless request.get? || request.head?

    # Sanitize q parameter - must be a String or nil, not a nested hash
    params[:q] = nil if params[:q].present? && !params[:q].is_a?(String)

    params[:search] ||= ActionController::Parameters.new

    deep_reject_blank = ->(hash) do
      hash.reject { |k, v| v.blank? || (v.is_a?(Hash) && deep_reject_blank.call(v).blank?) }
    end
    if params[:search].is_a?(ActionController::Parameters)
      nonblank_search_params = deep_reject_blank.call(params[:search])
    else
      nonblank_search_params = ActionController::Parameters.new
    end

    if nonblank_search_params != params[:search]
      params[:search] = nonblank_search_params
      redirect_to url_for(params: params.except(:controller, :action, :index).permit!)
    end
  end

  def search_params
    params.fetch(:search, {}).permit!
  end

  def permit_search_params(permitted_params)
    params.fetch(:search, {}).permit([:id, :created_at, :updated_at] + permitted_params)
  end
end
