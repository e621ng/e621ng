FactoryBot.define do
  factory(:artist_url) do
    artist
    sequence(:url) { |n| "artist_domain_#{n}.com" }
  end
end
