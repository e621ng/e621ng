# frozen_string_literal: true

module CloudflareService
  def self.endpoint
    "https://api.cloudflare.com/client/v4/ips"
  end

  def self.ips
    text, status = Cache.fetch("cloudflare_ips", expires_in: 24.hours) do
      resp = Faraday.new(Danbooru.config.faraday_options).get(endpoint)
      [resp.body, resp.status]
    end
    return [] if status != 200

    json = JSON.parse(text, symbolize_names: true)
    ips = json[:result][:ipv4_cidrs] + json[:result][:ipv6_cidrs]
    ips.map { |ip| IPAddr.new(ip) }
  end
end
