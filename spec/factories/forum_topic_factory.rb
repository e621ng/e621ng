# frozen_string_literal: true

FactoryBot.define do
  factory :forum_topic do
    title { "A forum topic" }
    category_id { create(:forum_category).id }
    original_post_attributes { { body: "This is the original post." } }
  end
end
