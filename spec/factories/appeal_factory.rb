# frozen_string_literal: true

FactoryBot.define do
  factory :appeal do
    qtype  { "flag" }
    reason { "This flag should be removed." }
    # creator and creator_ip_addr are set automatically from CurrentUser by the
    # belongs_to_creator before_validation hook. All specs must set CurrentUser
    # (e.g. via include_context "as member") before using this factory.

    transient do
      post_flag { create(:post_flag) }
    end

    after(:build) do |appeal, evaluator|
      appeal.disp_id = evaluator.post_flag.id
      appeal.send(:classify)
    end
  end
end
