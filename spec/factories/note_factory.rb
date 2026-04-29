# frozen_string_literal: true

FactoryBot.define do
  factory :note do
    # Post must be persisted — post_must_exist uses Post.exists?(post_id)
    post   { create(:post) } # 640×480 — default coords fit within image
    x      { 10 }
    y      { 10 }
    width  { 100 }
    height { 50 }
    body   { "A note body." }

    factory :inactive_note do
      is_active { false }
    end
  end
end
