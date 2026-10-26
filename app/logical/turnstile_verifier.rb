# frozen_string_literal: true

module TurnstileVerifier
  SITEVERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  MAX_TOKEN_LENGTH = 2048

  # Fails closed: any network or parse error counts as a failed challenge.
  def self.verify(token, remote_ip)
    return false if token.blank? || !token.is_a?(String) || token.length > MAX_TOKEN_LENGTH

    resp = Faraday.new(Danbooru.config.faraday_options).post(SITEVERIFY_URL) do |req|
      req.body = URI.encode_www_form(
        secret: Danbooru.config.turnstile_secret_key,
        response: token,
        remoteip: remote_ip,
      )
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
    end
    JSON.parse(resp.body)["success"] == true
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn("Turnstile verification failed: #{e.class}: #{e.message}")
    false
  end
end
