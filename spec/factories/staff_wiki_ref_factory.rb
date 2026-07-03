# frozen_string_literal: true

FactoryBot.define do
  factory :staff_wiki_ref do
    association :staff_wiki
    association :related, factory: :user
  end
end
