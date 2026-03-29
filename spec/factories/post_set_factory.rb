# frozen_string_literal: true

FactoryBot.define do
  sequence(:post_set_name)      { |n| "Post Set #{n}" }
  sequence(:post_set_shortname) { |n| "post_set_#{n}" }

  factory :post_set do
    name      { generate(:post_set_name) }
    shortname { generate(:post_set_shortname) }
    description { "" }
    is_public { false }
    post_ids  { [] }
    association :creator, factory: :user

    factory :public_post_set do
      is_public { true }
    end
  end
end
