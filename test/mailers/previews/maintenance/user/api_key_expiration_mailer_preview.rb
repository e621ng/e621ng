# frozen_string_literal: true

class Maintenance::User::ApiKeyExpirationMailerPreview < ActionMailer::Preview # rubocop:disable Style/ClassAndModuleChildren
  def expiration_notice
    key = ApiKey.where.not(expires_at: nil).first
    Maintenance::User::ApiKeyExpirationMailer.expiration_notice(key.user, key)
  end
end
