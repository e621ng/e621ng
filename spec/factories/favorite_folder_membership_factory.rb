# frozen_string_literal: true

FactoryBot.define do
  factory :favorite_folder_membership do
    user
    folder { association :favorite_folder, user: user }
    favorite { nil }
    post_id { favorite&.post_id }
    favorite_created_at { favorite&.created_at || Time.current }
  end
end
