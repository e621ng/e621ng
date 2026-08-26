# frozen_string_literal: true

FactoryBot.define do
  factory :upload_karma_event do
    association :user
    association :creator, factory: :user
    reason { :approved }
    delta { 1 }
    balance { 1 }
    extra_data { {} }
  end
end
