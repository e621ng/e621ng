# frozen_string_literal: true

FactoryBot.define do
  factory :tag_implication do
    sequence(:antecedent_name) { |n| "implication_from_#{n}" }
    sequence(:consequent_name) { |n| "implication_to_#{n}" }
    status { "pending" }

    factory :active_tag_implication do
      status { "active" }
    end

    factory :deleted_tag_implication do
      status { "deleted" }
    end
  end
end
