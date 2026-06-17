# frozen_string_literal: true

FactoryBot.define do
  sequence(:staff_wiki_title) { |n| "staff_wiki_#{n}" }

  factory :staff_wiki do
    title { generate(:staff_wiki_title) }
    body  { "Staff wiki body content." }
  end
end
