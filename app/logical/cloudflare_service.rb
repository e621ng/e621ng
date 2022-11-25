module CloudflareService
  def self.ips(expiry: 24.hours)
    text, code = Cache.get("cloudflare_ips", expiry) do
      resp = HTTParty.get("https://api.cloudflare.com/client/v4/ips", Danbooru.config.httparty_options)
      [resp.body, resp.code]
    end
    return [] if code != 200

    json = JSON.parse(text, symbolize_names: true)
    ips = json[:result][:ipv4_cidrs] + json[:result][:ipv6_cidrs]
    ips.map { |ip| IPAddr.new(ip) }
  end
end
