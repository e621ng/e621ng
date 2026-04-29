# frozen_string_literal: true

FactoryBot.define do
  factory(:forum_topic) do
    sequence(:title) { |n| "forum_topic_title_#{n}" }
    is_sticky { false }
    is_locked { false }
    category_id { Danbooru.config.alias_implication_forum_category }

    creator_ip_addr { "127.0.0.1" }

    transient do
      sequence(:body) { |n| "forum_topic_body_#{n}" }
    end

    after(:build) do |topic, evaluator|
      topic.original_post ||= build(:forum_post, topic: topic, body: evaluator.body)
    end

    before(:create) do |topic, evaluator|
      topic.original_post ||= build(:forum_post, topic: topic, body: evaluator.body)
    end
  end
end
