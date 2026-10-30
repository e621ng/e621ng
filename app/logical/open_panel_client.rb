# frozen_string_literal: true

module OpenPanelClient
  class Error < StandardError; end

  def self.enabled?
    Danbooru.config.openpanel_server_client_id.present? && Danbooru.config.openpanel_server_client_secret.present?
  end

  # Raises on failure so that the calling job can retry.
  def self.track(name, properties = {})
    resp = Faraday.new(Danbooru.config.faraday_options).post("#{Danbooru.config.openpanel_api_url}/track") do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["openpanel-client-id"] = Danbooru.config.openpanel_server_client_id
      req.headers["openpanel-client-secret"] = Danbooru.config.openpanel_server_client_secret
      req.body = { type: "track", payload: { name: name, properties: properties } }.to_json
    end
    raise Error, "OpenPanel track failed: HTTP #{resp.status}" unless resp.success?
  end
end
