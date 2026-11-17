# frozen_string_literal: true

# One row per browser login (doc 42). The cookie carries the row id and a random
# secret; only the secret's digest is stored. A row that is revoked or expired
# ends the login on the next request, whatever the cookie says.
class UserSession < ApplicationRecord
  IDLE_TIMEOUT = 7.days
  REMEMBER_TIMEOUT = 14.days
  MAX_ACTIVE = 50
  RETENTION = 30.days
  TOUCH_INTERVAL = 5.minutes
  # Rows never seen after login (scripted logins, parallel adoption of a legacy cookie)
  # are hidden and pruned after this long.
  UNTOUCHED_GRACE = 1.hour
  USER_AGENT_LIMIT = 1024

  belongs_to :user

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.now) }
  scope :touched, -> { where("last_seen_at > created_at") }
  # What the Sessions page lists: everything the user has used since logging in.
  scope :listed, -> { active.where("last_seen_at > created_at OR created_at > ?", UNTOUCHED_GRACE.ago) }

  def self.mint!(user, request:, remember:, legacy_key: nil)
    secret = SecureRandom.urlsafe_base64(32)
    now = Time.now
    record = create!(
      user: user,
      secret_digest: digest(secret),
      site: CurrentSite.id,
      remember: remember,
      user_agent: request.user_agent.to_s.scrub("").truncate(USER_AGENT_LIMIT),
      created_ip: request.remote_ip,
      last_ip: request.remote_ip,
      last_seen_at: now,
      expires_at: now + timeout_for(remember),
      legacy_key: legacy_key,
    )
    record.enforce_cap!
    [record, secret]
  end

  # The row the cookie names, if the secret matches. Does not check active?.
  def self.authenticate(sid, secret)
    return nil unless sid.present? && secret.is_a?(String) && secret.present?
    record = find_by(id: sid)
    return nil if record.nil?
    ActiveSupport::SecurityUtils.secure_compare(record.secret_digest, digest(secret)) ? record : nil
  end

  # A legacy cookie whose adopted row has been revoked (or has expired) must not
  # be able to mint a fresh row by replaying the old credential.
  def self.legacy_blocked?(user, key)
    where(user_id: user.id, legacy_key: key)
      .where("revoked_at IS NOT NULL OR expires_at <= ?", Time.now)
      .exists?
  end

  def self.revoke_all!(user, reason:, except: nil)
    scope = active.where(user_id: user.id)
    scope = scope.where.not(id: except.id) if except
    scope.update_all(revoked_at: Time.now, revoked_reason: reason)
  end

  def self.prune!
    without_timeout do
      where("revoked_at < :cutoff OR expires_at < :cutoff", cutoff: RETENTION.ago)
        .in_batches(load: false)
        .delete_all
      where("last_seen_at = created_at AND created_at < ?", UNTOUCHED_GRACE.ago)
        .in_batches(load: false)
        .delete_all
    end
  end

  def self.digest(secret)
    Digest::SHA256.hexdigest(secret)
  end

  def self.timeout_for(remember)
    remember ? REMEMBER_TIMEOUT : IDLE_TIMEOUT
  end

  def active?
    revoked_at.nil? && expires_at > Time.now
  end

  def touched?
    last_seen_at > created_at
  end

  def revoke!(reason)
    return if revoked_at.present?
    update_columns(revoked_at: Time.now, revoked_reason: reason)
  end

  def touch_activity!(request)
    now = Time.now
    update_columns(last_seen_at: now, last_ip: request.remote_ip, expires_at: now + self.class.timeout_for(remember))
  end

  # Called from a same-login re-confirmation that ticked "remember me".
  def remember!
    update_columns(remember: true, expires_at: Time.now + REMEMBER_TIMEOUT)
  end

  # Scripts that log in through the form on every run would otherwise grow the
  # list without bound. Untouched rows are left alone until the prune.
  def enforce_cap!
    overflow = self.class.active.touched.where(user_id: user_id).order(last_seen_at: :desc).offset(MAX_ACTIVE).pluck(:id)
    self.class.where(id: overflow).update_all(revoked_at: Time.now, revoked_reason: "cap") if overflow.any?
  end

  def hidden_attributes
    super + %i[secret_digest legacy_key]
  end
end
