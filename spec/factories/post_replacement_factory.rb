# frozen_string_literal: true

FactoryBot.define do
  factory :post_replacement do
    association     :post
    association     :creator, factory: :user
    creator_ip_addr { "127.0.0.1" }
    file_ext        { "jpg" }
    file_size       { 1_024 }
    image_width     { 100 }
    image_height    { 100 }
    sequence(:md5)  { |n| Digest::MD5.hexdigest("replacement_#{n}") }
    source          { "" }
    file_name       { "test.jpg" }
    storage_id      { SecureRandom.hex(16) }
    status          { "pending" }
    reason          { "A sufficient replacement reason" }
    is_backup       { true } # attr_accessor: suppresses create_original_backup callback

    to_create { |r| r.save!(validate: false) }

    factory :approved_post_replacement do
      status { "approved" }
      association :approver, factory: :user
    end

    factory :rejected_post_replacement do
      status { "rejected" }
      association :approver, factory: :user
    end

    factory :original_post_replacement do
      status { "original" }
      reason { "Backup of original file" }
    end

    factory :promoted_post_replacement do
      status { "promoted" }
      association :approver, factory: :user
    end
  end
end
