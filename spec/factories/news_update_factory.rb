# frozen_string_literal: true

FactoryBot.define do
  factory :news_update do
    creator { create(:admin_user) }

    message { "This is a news update." }
  end
end
