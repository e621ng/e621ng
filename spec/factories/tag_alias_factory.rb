# frozen_string_literal: true

FactoryBot.define do
  factory :tag_alias do
    sequence(:antecedent_name) { |n| "antecedent_tag_#{n}" }
    sequence(:consequent_name) { |n| "consequent_tag_#{n}" }
    status { "pending" }

    factory :active_tag_alias do
      status { "active" }
    end

    factory :deleted_tag_alias do
      status { "deleted" }
    end
  end
end
