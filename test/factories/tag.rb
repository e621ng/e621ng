# frozen_string_literal: true

FactoryBot.define do
  factory(:tag) do
    sequence(:name) { |n| "tag_name_#{n}" }
    post_count { 0 }
    category {Tag.categories.general}
    related_tags { "" }
    related_tags_updated_at {Time.now}

    factory(:artist_tag) do
      category {Tag.categories.artist}
    end

    factory(:copyright_tag) do
      category {Tag.categories.copyright}
    end

    factory(:character_tag) do
      category {Tag.categories.character}
    end
  end
end
