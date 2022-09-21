FactoryBot.define do
  factory(:post_set) do
    creator
    creator_ip_addr { "127.0.0.1" }
    name { FFaker::Lorem.words.join(" ") }
    shortname { FFaker::Lorem.words.join("_") }
  end
end
