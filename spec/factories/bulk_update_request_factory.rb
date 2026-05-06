# frozen_string_literal: true

FactoryBot.define do
  factory :bulk_update_request do
    association :user
    sequence(:script) { |n| "create alias bur_ant_#{n} -> bur_con_#{n}" }
    title { "A bulk update request" }
    skip_forum { true }

    factory :approved_bulk_update_request do
      after(:create) { |bur| bur.update_columns(status: "approved") }
    end

    factory :rejected_bulk_update_request do
      after(:create) { |bur| bur.update_columns(status: "rejected") }
    end
  end
end
