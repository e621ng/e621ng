FactoryBot.define do
  factory(:blip) do
    creator_ip_addr { "127.0.0.1" }
    sequence(:body) { |n| "blip_body_#{n}" }
  end
end
