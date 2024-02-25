# frozen_string_literal: true

FactoryBot.define do
  factory(:wiki_page) do
    creator factory: :user
    sequence(:title) { |n| "wiki_page_title_#{n}" }
    sequence(:body) { |n| "wiki_page_body_#{n}" }
  end
end
