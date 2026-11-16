# frozen_string_literal: true

FactoryBot.define do
  factory :forum_poll do
    transient do
      options_count { 2 }
    end

    forum_topic_id { create(:forum_topic).id }
    duration { ForumPoll::DEFAULT_DURATION }
    max_choices { 1 }

    after(:build) do |poll, evaluator|
      next if poll.options.any?
      evaluator.options_count.times { |i| poll.options.build(body: "Option #{i + 1}") }
    end
  end
end
