# frozen_string_literal: true

FactoryBot.define do
  factory :edit_history do
    body    { "Edit body text." }
    version { 1 }
    ip_addr { "127.0.0.1" }
    association :user
    association :versionable, factory: :blip
  end
end
