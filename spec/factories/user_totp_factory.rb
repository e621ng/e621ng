# frozen_string_literal: true

FactoryBot.define do
  factory :user_totp do
    association :user
    # Deterministic seed so specs can compute valid codes with ROTP::TOTP#at.
    secret { "JBSWY3DPEHPK3PXP" }
  end
end
