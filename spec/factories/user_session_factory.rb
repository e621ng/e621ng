# frozen_string_literal: true

FactoryBot.define do
  factory :user_session do
    user
    transient do
      secret { "factory-secret" }
    end
    secret_digest { UserSession.digest(secret) }
    site { CurrentSite.id }
    remember { false }
    user_agent { "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) Gecko/20100101 Firefox/132.0" }
    created_ip { "203.0.113.5" }
    last_ip { "203.0.113.5" }
    last_seen_at { Time.now }
    expires_at { Time.now + UserSession::IDLE_TIMEOUT }

    factory :remembered_user_session do
      remember { true }
      expires_at { Time.now + UserSession::REMEMBER_TIMEOUT }
    end

    factory :revoked_user_session do
      revoked_at { 1.minute.ago }
      revoked_reason { "user" }
    end
  end
end
