# frozen_string_literal: true

FactoryBot.define do
  factory(:dmail) do
    to factory: :user
    sequence(:title) { |n| "dmail_title_#{n}" }
    sequence(:body) { |n| "dmail_body_#{n}" }
  end
end
