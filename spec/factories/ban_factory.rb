# frozen_string_literal: true

FactoryBot.define do
  factory :ban do
    association :user
    # Banner must be persisted so level predicates (is_moderator?) return true (id.present? check).
    # Explicitly setting banner prevents initialize_banner_id from overwriting it with CurrentUser.id.
    banner { create(:moderator_user) }
    reason { "Test ban reason" }
    # The duration= setter writes expires_at and @duration; positive value = timed ban.
    duration { 30 }

    factory :permaban do
      # duration= with a negative value sets expires_at to nil (permanent ban).
      duration { -1 }
    end
  end
end
