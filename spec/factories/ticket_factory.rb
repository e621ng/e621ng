# frozen_string_literal: true

FactoryBot.define do
  factory :ticket do
    qtype  { "user" }
    reason { "This user is violating the rules." }

    transient do
      accused_user { create(:user) }
    end

    after(:build) do |ticket, evaluator|
      ticket.disp_id = evaluator.accused_user.id
      ticket.send(:classify)
    end

    trait :blip_type do
      qtype { "blip" }
      transient do
        blip { create(:blip) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id = evaluator.blip.id
        ticket.send(:classify)
      end
    end

    trait :comment_type do
      qtype { "comment" }
      transient do
        comment { create(:comment) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id = evaluator.comment.id
        ticket.send(:classify)
      end
    end

    trait :dmail_type do
      qtype { "dmail" }
      transient do
        dmail { create(:dmail) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id = evaluator.dmail.id
        ticket.send(:classify)
      end
    end

    trait :forum_type do
      qtype { "forum" }
      transient do
        forum_post { create(:forum_post) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id = evaluator.forum_post.id
        ticket.send(:classify)
      end
    end

    trait :pool_type do
      qtype { "pool" }
      transient do
        pool { create(:pool) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id = evaluator.pool.id
        ticket.send(:classify)
      end
    end

    trait :post_type do
      qtype { "post" }
      transient do
        post          { create(:post) }
        report_reason { create(:post_report_reason) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id       = evaluator.post.id
        ticket.report_reason = evaluator.report_reason.reason
        ticket.send(:classify)
      end
    end

    trait :set_type do
      qtype { "set" }
      transient do
        post_set { create(:post_set) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id = evaluator.post_set.id
        ticket.send(:classify)
      end
    end

    trait :wiki_type do
      qtype { "wiki" }
      transient do
        wiki_page { create(:wiki_page) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id = evaluator.wiki_page.id
        ticket.send(:classify)
      end
    end

    trait :replacement_type do
      qtype { "replacement" }
      transient do
        post_replacement { create(:post_replacement) }
      end
      after(:build) do |ticket, evaluator|
        ticket.disp_id = evaluator.post_replacement.id
        ticket.send(:classify)
      end
    end
  end
end
