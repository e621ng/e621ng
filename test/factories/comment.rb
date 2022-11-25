FactoryBot.define do
  factory(:comment) do
    post { create(:post) }
    sequence(:body) { |n| "comment_body_#{n}" }
  end
end
