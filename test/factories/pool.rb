FactoryBot.define do
  factory(:pool) do
    name {"pool_" + (rand(1_000_000) + 100).to_s}
    association :creator, factory: :user
    sequence(:description) { |n| "pool_description_#{n}" }
  end
end
