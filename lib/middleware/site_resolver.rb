# frozen_string_literal: true

module Middleware
  # Resolves which site a request is served as (doc 38), from the load
  # balancer's X-E6-Site header with the Host as a backstop.
  # Runs as middleware so that controllers outside ApplicationController
  # (Doorkeeper's token/userinfo endpoints, /status) see the site too.
  class SiteResolver
    def initialize(app)
      @app = app
    end

    def call(env)
      header = env["HTTP_X_E6_SITE"].to_s.strip.downcase
      # HTTP_HOST, not request.host: Rack would honour a client-sent X-Forwarded-Host
      host = env["HTTP_HOST"].to_s.strip.downcase.sub(/:\d+\z/, "")

      result = CurrentSite.resolve(header: header, host: host)
      return [400, { "Content-Type" => "text/plain" }, ["Unknown site"]] if result == :unknown

      site, safe = result
      # Always written, so nothing carries over from a previous request
      CurrentSite.apply!(site, safe)
      CurrentUser.safe_mode = CurrentSite.safe_mode?

      @app.call(env)
    end
  end
end
