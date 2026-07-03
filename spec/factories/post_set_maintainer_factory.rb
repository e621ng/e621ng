# frozen_string_literal: true

FactoryBot.define do
  factory :post_set_maintainer do
    # Requires a public set (ensure_set_public validation fires on create).
    # User must differ from the set's creator (ensure_not_set_owner validation).
    association :post_set, factory: :public_post_set
    association :user
    status { "pending" }

    factory :approved_post_set_maintainer do
      after(:create) { |m| m.update_columns(status: "approved") }
    end

    factory :blocked_post_set_maintainer do
      after(:create) { |m| m.update_columns(status: "blocked") }
    end
  end
end
