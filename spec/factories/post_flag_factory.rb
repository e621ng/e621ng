# frozen_string_literal: true

FactoryBot.define do
  factory :post_flag do
    post { create(:post) }
    # creator and creator_ip_addr are set automatically from CurrentUser by the
    # belongs_to_creator before_validation hook. All specs must set CurrentUser
    # (e.g. via include_context "as admin") before using this factory.

    transient do
      # Prefer a reason that doesn't require an explanation (simpler default, no mandatory note,
      # and avoids the uploading_guidelines branch in Post#delete!). Falls back to the first
      # non-special reason if every configured reason requires one.
      _default_reason_def do
        simple_reasons = Danbooru.config.flag_reasons.reject { |r| r[:name].to_s.in?(%w[inferior deletion]) }
        simple_reasons.find { |r| !r[:require_explanation] } || simple_reasons.first
      end
    end

    reason_name { _default_reason_def[:name].to_s }
    # reason is populated from reason_name by update_reason (validate :update_reason, on: :create).
    # For deletion flags where update_reason is a NOP, set reason directly on the sub-factory.
    note        { _default_reason_def[:require_explanation] ? "Generic note." : nil }
    is_resolved { false }
    is_deletion { false }

    factory :resolved_post_flag do
      is_resolved { true }
    end

    # Mirrors how Post#delete! creates deletion flags: reason_name "deletion" + is_deletion true.
    # validate_creator_is_not_limited is skipped when is_deletion is true.
    # update_reason is a NOP for "deletion", so reason must be set directly.
    factory :deletion_post_flag do
      is_deletion { true }
      reason_name { "deletion" }
      reason      { "Test deletion reason" }
      note        { nil }
    end
  end
end
