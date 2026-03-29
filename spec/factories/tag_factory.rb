# frozen_string_literal: true

FactoryBot.define do
  sequence(:tag_name) { |n| "tag_#{n}" }

  factory :tag do
    name     { generate(:tag_name) }
    category { 0 }
    post_count { 0 }

    factory :artist_tag do
      category { 1 }
    end

    factory :copyright_tag do
      category { 3 }
    end

    factory :character_tag do
      category { 4 }
    end

    factory :species_tag do
      category { 5 }
    end

    factory :invalid_tag do
      category { 6 }
    end

    factory :meta_tag do
      category { 7 }
    end

    factory :lore_tag do
      category { 8 }
    end

    factory :locked_tag do
      is_locked { true }
    end

    factory :high_post_count_tag do
      post_count { Danbooru.config.tag_type_change_cutoff + 50 }
    end
  end
end
