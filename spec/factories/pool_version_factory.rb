# frozen_string_literal: true

FactoryBot.define do
  factory :pool_version do
    transient do
      pool { create(:pool) }
    end

    pool_id { pool.id }
    association :updater, factory: :user
    post_ids { [] }
    description { "A pool description." }
    name { pool.name }
    is_active { true }
    category { "series" }
    updater_ip_addr { "127.0.0.1" }
  end
end
