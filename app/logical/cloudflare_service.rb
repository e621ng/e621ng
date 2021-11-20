# donmai.us specific

class CloudflareService
  def ips(expiry: 24.hours)
    text, code = HttpartyCache.get("https://api.cloudflare.com/client/v4/ips", expiry: expiry)
    return [] if code != 200

    json = JSON.parse(text, symbolize_names: true)
    ips = json[:result][:ipv4_cidrs] + json[:result][:ipv6_cidrs]
    ips.map { |ip| IPAddr.new(ip) }
  end
end
