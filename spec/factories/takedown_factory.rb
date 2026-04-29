# frozen_string_literal: true

FactoryBot.define do
  factory :takedown do
    email           { "takedown@example.com" }
    reason          { "This content infringes my copyright." }
    instructions    { "Please remove all matching artwork." }
    # belongs_to_creator sets creator_ip_addr from CurrentUser.ip_addr when creator_id is nil.
    # The explicit value here is a safe fallback for contexts where CurrentUser is not set.
    creator_ip_addr { "127.0.0.1" }
    # status, vericode, and del_post_ids are set by initialize_fields (before_validation on: :create).

    # Variant with a real post attached.
    # Pass `post:` to override the auto-created post.
    factory :takedown_with_post do
      transient do
        post { create(:post) }
      end

      after(:build) { |td, ev| td.post_ids = ev.post.id.to_s }

      # instructions must be nil so the takedown passes valid_posts_or_instructions via post_ids.
      instructions { nil }
    end
  end
end
