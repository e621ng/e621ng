class EmailBlacklist < ApplicationRecord
  UNVERIFY_COUNT_TRESHOLD = 250

  belongs_to_creator

  validates :domain, uniqueness: { case_sensitive: false, message: 'already exists' }
  after_create :invalidate_cache
  after_create :unverify_accounts
  after_destroy :invalidate_cache

  def self.is_banned?(email)
    email_domain = email.split('@').last.strip.downcase
    banned_domains = Cache.fetch("banned_emails", expires_in: 1.hour) do
      all.map { |x| x.domain.strip.downcase }.flatten
    end

    get_mx_records(email_domain).each do |mx_domain|
      return true if domain_matches?(banned_domains, mx_domain)
    end
    domain_matches?(banned_domains, email_domain)
  end

  def self.domain_matches?(banned_domains, domain)
    banned_domains.any? { |banned_domain| domain.end_with?(banned_domain) }
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
    return [] if Rails.env.test?
    Resolv::DNS.open do |dns|
      dns.getresources(domain, Resolv::DNS::Resource::IN::MX).map { |mx| mx.exchange.to_s }.flatten
    end
  end

  def invalidate_cache
    Cache.delete('banned_emails')
  end

  def unverify_accounts
    # Only unverify exact domain matches
    matching_users = User.search(email_matches: "*@#{domain}")
    return if matching_users.count > UNVERIFY_COUNT_TRESHOLD

    matching_users.each(&:mark_unverified!)
  end
end
