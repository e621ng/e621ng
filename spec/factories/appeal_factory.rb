# frozen_string_literal: true

FactoryBot.define do
  factory :appeal do
    qtype  { "post_deletion" }
    reason { "This deletion should be reverted." }
    # creator and creator_ip_addr are set automatically from CurrentUser by the
    # belongs_to_creator before_validation hook. All specs must set CurrentUser
    # (e.g. via include_context "as member") before using this factory.

    transient do
      post_deletion do
        post = create(:post)
        CurrentUser.scoped(create(:admin_user), "127.0.0.1") { post.delete!("Test deletion reason") }
        post.reload.current_deletion
      end
    end

    after(:build) do |appeal, evaluator|
      appeal.disp_id = evaluator.post_deletion.id
      appeal.send(:classify)
    end

    factory :post_deletion_appeal
  end
end
