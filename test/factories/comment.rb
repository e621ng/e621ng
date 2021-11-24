FactoryBot.define do
  factory(:comment) do
    post
    body { FFaker::Lorem.sentences.join(" ") }
    creator_ip_addr { "127.0.0.1" }
    creator factory: :user
  end
end
