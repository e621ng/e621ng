FactoryBot.define do
  factory(:forum_topic) do
    title { FFaker::Lorem.words.join(" ") }
    is_sticky { false }
    is_locked { false }
    category_id { Danbooru.config.alias_implication_forum_category }

    creator_ip_addr { "127.0.0.1" }

    transient do
      body { FFaker::Lorem.sentences.join(" ") }
    end

    after(:build) do |topic, evaluator|
      topic.original_post ||= build(:forum_post, topic: topic, body: evaluator.body)
    end

    before(:create) do |topic, evaluator|
      topic.original_post ||= build(:forum_post, topic: topic, body: evaluator.body)
    end
  end
end
