FactoryBot.define do
  factory(:post_disapproval) do
    reason { %w[borderline_quality borderline_relevancy other].sample }
    message { FFaker::Lorem.sentence }
  end
end
