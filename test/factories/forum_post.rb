# frozen_string_literal: true

FactoryBot.define do
  factory(:forum_post) do
    sequence(:body) { |n| "forum_post_body_#{n}" }
  end
end
