FactoryBot.define do
  factory :tag_alias do
    antecedent_name { "aaa" }
    consequent_name { "bbb" }
    status { "active" }
    creator_ip_addr { FFaker::Internet.ip_v4_address }

    factory(:tag_alias_with_topic) do
      forum_topic
    end
  end
end
