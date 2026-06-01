# frozen_string_literal: true

require "faker"

FactoryBot.define do
  factory :user, aliases: [:member_user] do
    name { generate_username }
    level { UserLevel::MEMBER }
    created_at { Time.now - 2.weeks }
    email { "#{(name || '').downcase}@example.com" }
    password { "hexerade" }
    password_confirmation { "hexerade" }
    last_logged_in_at { Time.now }
    last_ip_addr { Faker::Internet.ip_v4_address }

    transient do
      disable_sock_puppet_validation { true }
    end

    after(:build) do |_user, evaluator|
      instance = RSpec.current_example.example_group_instance
      instance.allow(Danbooru.config.custom_configuration)
              .to instance.receive(:enable_sock_puppet_validation?)
              .and_return(!evaluator.disable_sock_puppet_validation)
    end

    #########################
    ###### User Levels ######
    #########################

    factory :anonymous_user do
      name { "Anonymous" }
      level { UserLevel::ANONYMOUS }
    end

    factory :banned_user do
      level { UserLevel::BLOCKED }
    end

    factory :privileged_user do
      level { UserLevel::PRIVILEGED }
    end

    factory :former_staff_user do
      level { UserLevel::FORMER_STAFF }
    end

    factory :janitor_user do
      level { UserLevel::JANITOR }
    end

    factory :moderator_user do
      level { UserLevel::MODERATOR }
    end

    factory :admin_user do
      level { UserLevel::ADMIN }
    end

    # Legacy option
    factory(:bd_staff_user) do
      is_bd_staff { true }
      level { UserLevel::ADMIN }
      can_approve_posts { true }
    end

    factory(:bd_member_user) do
      is_bd_staff { true }
      level { UserLevel::MEMBER }
    end

    factory(:bd_janitor_user) do
      is_bd_staff { true }
      level { UserLevel::JANITOR }
    end

    factory(:bd_moderator_user) do
      is_bd_staff { true }
      level { UserLevel::MODERATOR }
    end

    factory(:bd_admin_user) do
      is_bd_staff { true }
      level { UserLevel::ADMIN }
    end

    #########################
    ### Permission Flags ####
    #########################

    factory :unlimited_uploads_user do
      can_upload_free { true }
    end

    factory :approver_user do
      can_approve_posts { true }
    end

    factory :bd_auditor_user do
      is_bd_auditor { true }
    end

    factory :unverified_user do
      email_verification_key { "1" }
    end
  end
end

def generate_username
  loop do
    @username = generate_username_candidate
    next unless @username.length >= 3 && @username.length <= 20
    next unless User.find_by(name: @username).nil?
    break
  end

  @username
end

def generate_username_candidate
  [
    Faker::Adjective.positive.split.each(&:capitalize!),
    Faker::Creature::Animal.name.split.each(&:capitalize!),
  ].concat.join("_")
end
