# frozen_string_literal: true

FactoryBot.define do
  factory :post_flag do

    post { create(:post) }
    # creator and creator_ip_addr are set automatically from CurrentUser by the
    # belongs_to_creator before_validation hook. All specs must set CurrentUser
    # (e.g. via include_context "as admin") before using this factory.

    reason_name { "guidelines" }
    is_resolved { false }
    is_deletion { false }
    note        { nil }

    factory :needs_staff_reason_post_flag do
      reason_name { "needs_staff_reason" }
    end

    factory :needs_parent_id_post_flag do
      reason_name { "needs_parent_id" }
    end

    factory :needs_explanation_post_flag do
      reason_name { "needs_explanation" }
    end

    factory :grandfathering_post_flag do
      reason_name { "grandfathering" }
    end

    factory :resolved_post_flag do
      is_resolved { true }
    end

    # Mirrors how Post#delete! creates deletion flags: reason_name "deletion" + is_deletion true.
    # validate_creator_is_not_limited is skipped when is_deletion is true.
    # update_reason is a NOP for "deletion", so reason must be set directly.
    factory :deletion_post_flag do
      reason_name { "deletion" }
      is_deletion { true }
      reason      { "Test deletion reason" }
    end
  end
end
