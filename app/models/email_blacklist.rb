class EmailBlacklist < ApplicationRecord
  belongs_to_creator

  validates :domain, uniqueness: { case_sensitive: false, message: 'already exists' }
  after_save :invalidate_cache
  after_destroy :invalidate_cache

  def self.is_banned?(email)
    email_domain = email.split('@').last.strip.downcase
    banned_domains = Cache.get('banned_emails', 1.hour) do
      all().map {|x| x.domain.strip.downcase}.flatten
    end
    return true if get_mx_records(email_domain).count {|x| banned_domains.count {|y| x.ends_with?(y)} > 0} > 0
    banned_domains.count {|x| email_domain.end_with?(x)} > 0
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

    params[:order] ||= params.delete(:sort)
    case params[:order]
    when "reason"
      q = q.order("email_blacklists.reason")
    when "domain"
      q = q.order("email_blacklists.domain")
    when "updated_at"
      q = q.order("email_blacklists.updated_at desc")
    else
      q = q.apply_default_order(params)
    end

    q
  end

  def self.get_mx_records(domain)
    return [] if Rails.env.test?
    Resolv::DNS.open do |dns|
      dns.getresources(domain, Resolv::DNS::Resource::IN::MX).map {|x| x.exchange.to_s }.flatten
    end
  end

  def invalidate_cache
    Cache.delete('banned_emails')
  end
end
