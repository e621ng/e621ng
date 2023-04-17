class IqdbQueriesController < ApplicationController
  respond_to :html, :json
  before_action :detect_xhr, :throttle

  def show
    if params[:v2].present?
      new_version
    else
      old_version
    end

    respond_with(@matches) do |fmt|
      fmt.html do |html|
        html.xhr { render layout: false }
      end

      fmt.json do
        render json: @matches, root: "posts"
      end
    end
  rescue IqdbProxy::Error, IqdbProxyNew::Error => e
    render_expected_error(500, e.message)
  end

  private

  def old_version
    if params[:file]
      @matches = IqdbProxy.query_file(params[:file].tempfile)
    elsif params[:url].present?
      parsed_url = Addressable::URI.heuristic_parse(params[:url]) rescue nil
      raise User::PrivilegeError "Invalid URL" unless parsed_url
      whitelist_result = UploadWhitelist.is_whitelisted?(parsed_url)
      raise User::PrivilegeError "Not allowed to request content from this URL" unless whitelist_result[0]
      @matches = IqdbProxy.query(params[:url])
    elsif params[:post_id]
      @matches = IqdbProxy.query_path(Post.find(params[:post_id]).preview_file_path)
    end
  end

  def new_version
    if params[:file]
      @matches = iqdb_proxy(:query_file, params[:file].tempfile)
    elsif params[:url].present?
      parsed_url = Addressable::URI.heuristic_parse(params[:url]) rescue nil
      raise User::PrivilegeError, "Invalid URL" unless parsed_url
      whitelist_result = UploadWhitelist.is_whitelisted?(parsed_url)
      raise User::PrivilegeError, "Not allowed to request content from this URL" unless whitelist_result[0]
      @matches = iqdb_proxy(:query_url, params[:url])
    elsif params[:post_id]
      @matches = iqdb_proxy(:query_post, Post.find(params[:post_id]))
    elsif params[:hash]
      @matches = iqdb_proxy(:query_hash, params[:hash])
    end
  end

  def iqdb_proxy(method, value)
    IqdbProxyNew.send(method, value, params[:score_cutoff])
  end

  def throttle
    if params[:file] || params[:url] || params[:post_id]
      if RateLimiter.check_limit("img:#{CurrentUser.ip_addr}", 1, 2.seconds) && !Danbooru.config.disable_throttles?
        raise APIThrottled
      else
        RateLimiter.hit("img:#{CurrentUser.ip_addr}", 2.seconds)
      end
    end
  end

  def detect_xhr
    if request.xhr?
      request.variant = :xhr
    end
  end
end
