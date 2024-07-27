# frozen_string_literal: true

FactoryBot.define do
  factory :tag_implication do
    antecedent_name { "aaa" }
    consequent_name { "bbb" }
    status { "active" }
    creator_ip_addr { "127.0.0.1" }
  end
end
