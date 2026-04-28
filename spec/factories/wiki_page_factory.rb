# frozen_string_literal: true

FactoryBot.define do
  sequence(:wiki_page_title) { |n| "wiki_page_#{n}" }

  factory :wiki_page do
    title       { generate(:wiki_page_title) }
    body        { "Wiki page body." }
    is_locked   { false }
    is_deleted  { false }
    parent      { nil }
    other_names { [] }

    factory :locked_wiki_page do
      is_locked { true }
    end

    factory :deleted_wiki_page do
      is_deleted { true }
    end

    factory :wiki_page_with_other_names do
      other_names { %w[alias_one alias_two] }
    end

    factory :wiki_page_with_body_links do
      body { "See [[some_tag]] and [[display text|other_tag]]." }
    end
  end
end
