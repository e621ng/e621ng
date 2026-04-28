# frozen_string_literal: true

FactoryBot.define do
  factory :post_event do
    association :creator, factory: :user
    action { :deleted }
    post_id { create(:post).id }
    extra_data { {} }
  end
end
