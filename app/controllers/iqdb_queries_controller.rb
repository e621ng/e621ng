class IqdbQueriesController < ApplicationController
  respond_to :html, :json
  before_action :detect_xhr, :throttle

  def show
    if params[:file]
      @matches = IqdbProxy.query_file(params[:file])
    elsif params[:url].present?
      parsed_url = Addressable::URI.heuristic_parse(params[:url]) rescue nil
      raise User::PrivilegeError.new("Invalid URL") unless parsed_url
      whitelist_result = UploadWhitelist.is_whitelisted?(parsed_url)
      raise User::PrivilegeError.new("Not allowed to request content from this URL") unless whitelist_result[0]
      @matches = IqdbProxy.query(params[:url])
    elsif params[:post_id]
      @matches = IqdbProxy.query_path(Post.find(params[:post_id]).preview_file_path)
    end

    respond_with(@matches) do |fmt|
      fmt.html do |html|
        html.xhr { render layout: false}
      end

      fmt.json do
        render json: @matches, root: 'posts'
      end
    end
  rescue IqdbProxy::Error => e
    render_expected_error(500, e.message)
  end

private

  def throttle
    if params[:file] || params[:url] || params[:post_id]
      unless RateLimiter.check_limit("img:#{CurrentUser.ip_addr}", 1, 2.seconds)
        RateLimiter.hit("img:#{CurrentUser.ip_addr}", 2.seconds)
      else
        raise APIThrottled.new
      end
    end
  end

  def detect_xhr
    if request.xhr?
      request.variant = :xhr
    end
  end
end
