# frozen_string_literal: true

FactoryBot.define do
  factory :staff_wiki_version do
    association :staff_wiki
    title           { generate(:staff_wiki_title) }
    body            { "Staff wiki version body." }
    claimant_id     { nil }
    updater_ip_addr { "127.0.0.1" }
  end
end
