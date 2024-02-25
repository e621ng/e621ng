# frozen_string_literal: true

module CloudflareService
  def self.ips
    text, code = Cache.fetch("cloudflare_ips", expires_in: 24.hours) do
      resp = HTTParty.get("https://api.cloudflare.com/client/v4/ips", Danbooru.config.httparty_options)
      [resp.body, resp.code]
    end
    return [] if code != 200

    json = JSON.parse(text, symbolize_names: true)
    ips = json[:result][:ipv4_cidrs] + json[:result][:ipv6_cidrs]
    ips.map { |ip| IPAddr.new(ip) }
  end
end
