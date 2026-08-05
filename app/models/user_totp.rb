# frozen_string_literal: true

class UserTotp < ApplicationRecord
  BACKUP_CODE_COUNT = 10
  DRIFT = 30

  belongs_to :user

  # The totp_enabled bit pref gates the per-request password_token check, so it must never drift.
  after_create { sync_user_flag(true) }
  after_destroy { sync_user_flag(false) }

  def self.generate_secret
    ROTP::Base32.random
  end

  # Atomic bit flip so a concurrent write to another bit_prefs flag can't be clobbered.
  def self.set_user_flag(user_id, enabled)
    mask = User.flag_value_for("totp_enabled")
    operation = enabled ? "bit_prefs | #{mask}" : "bit_prefs & ~#{mask}"
    User.where(id: user_id).update_all("bit_prefs = #{operation}")
  end

  def self.encryptor
    key = [Danbooru.config.totp_encryption_key].pack("H*")
    ActiveSupport::MessageEncryptor.new(key, purpose: "totp_secret")
  end

  def secret=(base32_secret)
    self.secret_ciphertext = self.class.encryptor.encrypt_and_sign(base32_secret)
  end

  def secret
    self.class.encryptor.decrypt_and_verify(secret_ciphertext)
  end

  def totp
    ROTP::TOTP.new(secret, issuer: Danbooru.config.totp_issuer)
  end

  def provisioning_uri
    totp.provisioning_uri(user.name)
  end

  # Single verification entry point for the login challenge, disable, and backup code
  # regeneration. Accepts a 6-digit TOTP code or a backup code; returns :totp or
  # :backup_code on success, nil on failure. Consumes state on success (last_used_step
  # for TOTP replay prevention, the digest for backup codes).
  def verify_code!(input)
    code = input.to_s.gsub(/[\s-]/, "").downcase
    if code.match?(/\A\d{6}\z/)
      # rotp returns the matched step's Unix timestamp; after: rejects that step and
      # everything before it, so an accepted code can never be replayed.
      timestamp = totp.verify(code, drift_behind: DRIFT, drift_ahead: DRIFT, after: last_used_step)
      return nil unless timestamp
      update_columns(last_used_step: timestamp, updated_at: Time.now)
      :totp
    else
      consume_backup_code(code)
    end
  end

  def regenerate_backup_codes!
    codes = Array.new(BACKUP_CODE_COUNT) { SecureRandom.hex(8).scan(/.{4}/).join("-") }
    update!(backup_code_digests: codes.map { |code| digest_code(code) })
    codes
  end

  private

  def sync_user_flag(enabled)
    self.class.set_user_flag(user_id, enabled)
    user.totp_enabled = enabled
  end

  def consume_backup_code(code)
    digest = digest_code(code)
    matched = backup_code_digests.find { |stored| ActiveSupport::SecurityUtils.secure_compare(stored, digest) }
    return nil unless matched
    update!(backup_code_digests: backup_code_digests - [matched])
    :backup_code
  end

  def digest_code(code)
    Digest::SHA256.hexdigest(code.gsub(/[\s-]/, "").downcase)
  end
end
