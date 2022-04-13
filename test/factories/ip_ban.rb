FactoryBot.define do
  factory(:ip_ban) do
    creator
    reason { FFaker::Lorem.words.join(" ") }
  end
end
