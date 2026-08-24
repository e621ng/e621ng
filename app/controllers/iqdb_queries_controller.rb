# frozen_string_literal: true

class IqdbQueriesController < ApplicationController
  respond_to :html, :json
  # CSRF is skipped only for read-only image similarity queries that don't modify data.
  # This enables API access for external tools while the queries themselves are harmless.
  skip_forgery_protection only: :show
  before_action :validate_enabled

  def show
    # Allow legacy ?post_id=123 parameters
    search_params = params[:search].presence || params
    throttle(search_params)

    v2_format = params[:v2] == "true" && request.format.json?

    @matches = []
    if search_params[:file].present?
      unless search_params[:file].respond_to?(:tempfile)
        return render_iqdb_error(400, "The uploaded file could not be processed. Please try a different file.")
      end
      @matches = IqdbProxy.query_file(search_params[:file].tempfile, search_params[:score_cutoff], v2_format: v2_format)
    elsif search_params[:url].present?
      return render_iqdb_error(400, "The URL must begin with http:// or https://.") unless search_params[:url].is_a?(String)
      parsed_url = begin
        # Scheme-less input gets https prepended; explicit schemes pass through untouched.
        Addressable::URI.heuristic_parse(search_params[:url], scheme: "https")
      rescue StandardError
        nil
      end
      unless parsed_url&.scheme.in?(%w[http https]) && parsed_url.host.present?
        return render_iqdb_error(400, "The URL must begin with http:// or https://.")
      end
      whitelist_result = UploadWhitelist.is_whitelisted?(parsed_url)
      return render_iqdb_error(400, "Not allowed to request content from this URL") unless whitelist_result[0]
      @matches = IqdbProxy.query_url(parsed_url.to_s, search_params[:score_cutoff], v2_format: v2_format)
    elsif search_params[:post_id].present?
      unless search_params[:post_id].to_s =~ /\A\d+\z/
        return render_iqdb_error(400, "Please enter a valid post ID.")
      end
      @matches = IqdbProxy.query_post(search_params[:post_id], search_params[:score_cutoff], v2_format: v2_format)
    elsif search_params[:hash].present?
      unless search_params[:hash].is_a?(String) && search_params[:hash] =~ /\A[0-9a-fA-F]+\z/
        return render_iqdb_error(400, "Please enter a valid MD5 hash.")
      end
      @matches = IqdbProxy.query_hash(search_params[:hash], search_params[:score_cutoff], v2_format: v2_format)
    end

    respond_with(@matches) do |fmt|
      fmt.json do
        render json: @matches, root: "posts"
      end
    end
  rescue Downloads::File::Error => e
    render_iqdb_error(422, e.message)
  rescue IqdbProxy::BusyError => e
    render_iqdb_error(429, e.message)
  rescue IqdbProxy::Error => e
    # Covers CircuitOpenError too — both are availability problems.
    render_iqdb_error(503, e.message)
  end

  private

  # Expected failures re-render the search form with an inline error instead of
  # the dead-end static error page. Non-HTML formats keep the standard error shape.
  def render_iqdb_error(status, message)
    if request.format.html?
      @error = message
      @matches ||= []
      render :show, status: status
    else
      render_expected_error(status, message)
    end
  end

  def throttle(search_params)
    return if Danbooru.config.disable_throttles?

    if %i[file url].any? { |key| search_params[key].present? }
      # Heavy throttles for file and URL queries
      enforce_throttle!(
        type: "heavy",
        anon_limit: 1,
        anon_period: 60.seconds,
        user_limit: 6,
        user_period: 10.seconds,
      )
    elsif %i[post_id hash].any? { |key| search_params[key].present? }
      # Lighter throttles for post_id and hash queries
      enforce_throttle!(
        type: "light",
        anon_limit: 10,
        anon_period: 10.seconds,
        user_limit: 10,
        user_period: 10.seconds,
      )
    end
  end

  def enforce_throttle!(type:, anon_limit:, anon_period:, user_limit:, user_period:)
    if CurrentUser.user.is_anonymous?
      raise APIThrottled if IqdbProxy.anon_lockdown?
      raise APIThrottled if RateLimiter.throttle!("eris:#{type}:anon:#{CurrentUser.ip_addr}", limit: anon_limit, period: anon_period)
    else
      ip_limiter = RateLimiter.new("eris:#{type}:#{CurrentUser.ip_addr}", limit: user_limit, period: user_period)
      user_limiter = RateLimiter.new("eris:#{type}:user:#{CurrentUser.user.id}", limit: user_limit, period: user_period)
      raise APIThrottled if ip_limiter.throttled? || user_limiter.throttled?
      ip_limiter.hit!
      user_limiter.hit!
    end
  end

  def validate_enabled
    raise FeatureUnavailable unless IqdbProxy.enabled?
  end
end
