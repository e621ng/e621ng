# frozen_string_literal: true

FactoryBot.define do
  factory :post do
    # Force persistence so uploader_id is always set (needed by initialize_uploader check).
    uploader         { create(:user) }
    sequence(:md5)   { |n| Digest::MD5.hexdigest(n.to_s) }
    rating           { "s" }
    file_ext         { "jpg" }
    image_width      { 640 }
    image_height     { 480 }
    file_size        { 10_000 }
    uploader_ip_addr { "127.0.0.1" }

    # Unique director + 10 general tags per factory call.
    # normalize_tags (before_validation) auto-creates them via Tag.find_or_create_by_name_list.
    sequence(:tag_string) { |n| "director:factory_director_#{n} " + (1..10).map { |i| "factory_tag_#{n}_#{i}" }.join(" ") }

    factory :pending_post do
      is_pending { true }
    end

    factory :deleted_post do
      is_pending { false }
      is_deleted { true }
    end

    factory :flagged_post do
      is_flagged { true }
    end

    factory :rating_locked_post do
      is_rating_locked { true }
    end

    factory :note_locked_post do
      is_note_locked { true }
    end

    factory :status_locked_post do
      is_status_locked { true }
    end
  end
end
