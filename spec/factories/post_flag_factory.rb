# frozen_string_literal: true

FactoryBot.define do
  factory :post_flag do
    post { create(:post) }
    # creator and creator_ip_addr are set automatically from CurrentUser by the
    # belongs_to_creator before_validation hook. All specs must set CurrentUser
    # (e.g. via include_context "as admin") before using this factory.

    reason_name { PostFlagReason.by_name("basic")&.name || create(:post_flag_reason).name }

    is_resolved { false }
    note        { nil }

    factory :needs_staff_reason_post_flag do
      reason_name { PostFlagReason.by_name("needs_staff_reason")&.name || create(:needs_staff_reason_post_flag_reason).name }
    end

    factory :needs_parent_id_post_flag do
      reason_name { PostFlagReason.by_name("needs_parent_id")&.name || create(:needs_parent_id_post_flag_reason).name }
    end

    factory :needs_explanation_post_flag do
      reason_name { PostFlagReason.by_name("needs_explanation")&.name || create(:needs_explanation_post_flag_reason).name }
    end

    factory :grandfathering_post_flag do
      reason_name { PostFlagReason.by_name("grandfathering")&.name || create(:grandfathering_post_flag_reason).name }
    end

    factory :resolved_post_flag do
      is_resolved { true }
    end
  end

  # A deletion flag as the old Post#delete! wrote it. The model no longer creates these,
  # so it is inserted directly, skipping validations and callbacks.
  factory :legacy_deletion_post_flag, class: "PostFlag" do
    post { create(:deleted_post) }
    creator { CurrentUser.user }
    creator_ip_addr { "127.0.0.1" }
    reason_name { "deletion" }
    reason { "Test deletion reason" }
    is_deletion { true }
    is_resolved { false }

    to_create do |flag|
      attrs = flag.attributes.except("id").compact
      flag.id = PostFlag.unscoped.insert!(attrs, returning: :id).first["id"]
    end
  end
end
