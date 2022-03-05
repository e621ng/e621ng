FactoryBot.define do
  factory(:forum_topic) do
    title {FFaker::Lorem.words.join(" ")}
    is_sticky { false }
    is_locked { false }
    category_id { Danbooru.config.alias_implication_forum_category }
  end
end
