FactoryBot.define do
  factory(:blip) do
    creator
    creator_ip_addr { "127.0.0.1" }
    body { FFaker::Lorem.sentences.join(" ") }
  end
end
