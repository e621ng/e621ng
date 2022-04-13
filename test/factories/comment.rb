FactoryBot.define do
  factory(:comment) do
    post { create(:post) }
    body { FFaker::Lorem.sentences.join(" ") }
  end
end
