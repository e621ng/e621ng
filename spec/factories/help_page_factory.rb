# frozen_string_literal: true

FactoryBot.define do
  sequence(:help_page_name) { |n| "help_page_#{n}" }

  factory :help_page do
    association :wiki, factory: :wiki_page
    name      { generate(:help_page_name) }
    wiki_page { wiki.title }
    related   { "" }
    title     { "" }
  end
end
