FactoryBot.define do
  factory :tag_implication do
    antecedent_name { "aaa" }
    consequent_name { "bbb" }
    status { "active" }

    factory(:tag_implication_with_topic) do
      forum_topic
    end
  end
end
