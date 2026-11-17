# frozen_string_literal: true

class EmailBlacklist < ApplicationRecord
  UNVERIFY_COUNT_TRESHOLD = 250
  BANNED_CACHE_KEY = "banned_emails_1"

  # alphanumeric and hyphens (except leading or trailing), 1-63 chars per part, at least 2 parts
  DOMAIN_PART = /(?!-)[a-z0-9-]{1,63}(?<!-)/
  DOMAIN_FORMAT = /\A#{DOMAIN_PART}(?:\.#{DOMAIN_PART})+\z/

  belongs_to_creator

  before_validation :normalize_domain_attribute

  validates :domain, presence: true
  validates :domain, length: { maximum: 253 }
  validates :domain,
            format: {
              with: DOMAIN_FORMAT,
              message: "must be a plain domain name like example.com (no wildcards, no @)",
            },
            allow_blank: true
  validates :domain, uniqueness: { case_sensitive: false, message: "already exists" }

  after_create :invalidate_cache
  after_create :unverify_accounts
  after_destroy :invalidate_cache

  def self.is_banned?(email)
    return false if email.blank? || email.exclude?("@")
    parts = email.split("@")
    return false if parts.length != 2 || parts.any?(&:blank?)
    email_domain = normalize_domain(parts.last)
    return false if email_domain.blank?

    banned_domains = banned_domain_set
    return false if banned_domains.empty?

    return true if domain_matches?(banned_domains, email_domain)
    get_mx_records(email_domain).any? { |mx_domain| domain_matches?(banned_domains, mx_domain) }
  end

  # Only match at domain boundaries (don't match partial names).
  def self.domain_matches?(banned_domains, domain)
    labels = normalize_domain(domain).split(".")

    # Don't match TLDs
    (0...(labels.length - 1)).any? do |i|
      banned_domains.include?(labels[i..].join("."))
    end
  end

  def self.normalize_domain(domain)
    domain.to_s.strip.downcase.chomp(".")
  end

  def self.banned_domain_set
    Cache.fetch(BANNED_CACHE_KEY, expires_in: 1.hour) do
      all.map { |x| normalize_domain(x.domain) }.compact_blank.to_set
    end
  end

  def self.search(params)
    q = super

    q = q.includes(:creator)

    if params[:domain].present?
      q = q.where("domain ILIKE ?", params[:domain].to_escaped_for_sql_like)
    end

    if params[:reason].present?
      q = q.where("reason ILIKE ?", params[:reason].to_escaped_for_sql_like)
    end

    case params[:order]
    when "reason"
      q = q.order("email_blacklists.reason")
    when "domain"
      q = q.order("email_blacklists.domain")
    else
      q = q.apply_basic_order(params)
    end

    q
  end

  def self.get_mx_records(domain)
    return [] if Rails.env.local?
    Resolv::DNS.open do |dns|
      dns.getresources(
        domain,
        Resolv::DNS::Resource::IN::MX,
      ).map { |mx| mx.exchange.to_s.force_encoding("UTF-8") }.flatten
    end
  rescue Resolv::ResolvError, Resolv::ResolvTimeout
    []
  end

  def invalidate_cache
    Cache.delete(BANNED_CACHE_KEY)
  end

  def unverify_accounts
    # Only unverify exact domain matches
    matching_users = User.search(email_matches: "*@#{domain}")
    return if matching_users.count > UNVERIFY_COUNT_TRESHOLD

    matching_users.each(&:mark_unverified!)
  end

  private

  def normalize_domain_attribute
    self.domain = self.class.normalize_domain(domain) if domain.present?
  end
end
