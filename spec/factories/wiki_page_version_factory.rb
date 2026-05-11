# frozen_string_literal: true

FactoryBot.define do
  factory :wiki_page_version do
    association :wiki_page
    title           { generate(:wiki_page_title) }
    body            { "Wiki page version body." }
    is_locked       { false }
    is_deleted      { false }
    other_names     { [] }
    updater_ip_addr { "127.0.0.1" }
    reason          { nil }
    parent          { nil }
  end
end
