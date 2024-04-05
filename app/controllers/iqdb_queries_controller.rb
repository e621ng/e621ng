# frozen_string_literal: true

class IqdbQueriesController < ApplicationController
  respond_to :html, :json
  # Show uses POST because it needs a file parameter. This would be GET otherwise.
  skip_forgery_protection only: :show
  before_action :validate_enabled

  def show
    # Allow legacy ?post_id=123 parameters
    search_params = params[:search].presence || params
    throttle(search_params)

    @matches = []
    if search_params[:file].present?
      @matches = IqdbProxy.query_file(search_params[:file].tempfile, search_params[:score_cutoff])
    elsif search_params[:url].present?
      parsed_url = Addressable::URI.heuristic_parse(search_params[:url]) rescue nil
      raise User::PrivilegeError, "Invalid URL" unless parsed_url
      whitelist_result = UploadWhitelist.is_whitelisted?(parsed_url)
      raise User::PrivilegeError, "Not allowed to request content from this URL" unless whitelist_result[0]
      @matches = IqdbProxy.query_url(search_params[:url], search_params[:score_cutoff])
    elsif search_params[:post_id].present?
      @matches = IqdbProxy.query_post(Post.find_by(id: search_params[:post_id]), search_params[:score_cutoff])
    elsif search_params[:hash].present?
      @matches = IqdbProxy.query_hash(search_params[:hash], search_params[:score_cutoff])
    end

    respond_with(@matches) do |fmt|
      fmt.json do
        render json: @matches, root: "posts"
      end
    end
  rescue IqdbProxy::Error => e
    render_expected_error(500, e.message)
  end

  private

  def throttle(search_params)
    return if Danbooru.config.disable_throttles?

    if %i[file url post_id hash].any? { |key| search_params[key].present? }
      if RateLimiter.check_limit("img:#{CurrentUser.ip_addr}", 1, 2.seconds)
        raise APIThrottled
      else
        RateLimiter.hit("img:#{CurrentUser.ip_addr}", 2.seconds)
      end
    end
  end

  def validate_enabled
    raise FeatureUnavailable if Danbooru.config.iqdb_server.blank?
  end
end
