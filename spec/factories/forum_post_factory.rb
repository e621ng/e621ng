# frozen_string_literal: true

FactoryBot.define do
  factory :forum_post do
    topic_id { create(:forum_topic).id }
    body { "This is a forum post." }
    bypass_limits { true }
  end
end
