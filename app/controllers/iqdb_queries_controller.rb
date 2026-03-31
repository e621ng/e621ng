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

    @matches = []
    if search_params[:file].present?
      raise ProcessingError, "Invalid file parameter" unless search_params[:file].respond_to?(:tempfile)
      @matches = IqdbProxy.query_file(search_params[:file].tempfile, search_params[:score_cutoff])
    elsif search_params[:url].present?
      raise ProcessingError, "Invalid URL parameter" unless search_params[:url].is_a?(String)
      parsed_url = begin
        Addressable::URI.heuristic_parse(search_params[:url])
      rescue StandardError
        nil
      end
      raise ProcessingError, "Invalid URL" unless parsed_url
      whitelist_result = UploadWhitelist.is_whitelisted?(parsed_url)
      raise ProcessingError, "Not allowed to request content from this URL" unless whitelist_result[0]
      @matches = IqdbProxy.query_url(parsed_url.to_s, search_params[:score_cutoff])
    elsif search_params[:post_id].present?
      raise ProcessingError, "Invalid post_id parameter" unless search_params[:post_id].to_s =~ /\A\d+\z/
      @matches = IqdbProxy.query_post(Post.find_by(id: search_params[:post_id]), search_params[:score_cutoff])
    elsif search_params[:hash].present?
      raise ProcessingError, "Invalid hash parameter" unless search_params[:hash].is_a?(String) && search_params[:hash] =~ /\A[0-9a-fA-F]+\z/
      @matches = IqdbProxy.query_hash(search_params[:hash], search_params[:score_cutoff])
    end

    respond_with(@matches) do |fmt|
      fmt.json do
        render json: @matches, root: "posts"
      end
    end
  rescue Downloads::File::Error
    render_expected_error(404, "File not found or too large")
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
    raise FeatureUnavailable unless IqdbProxy.enabled?
  end
end
