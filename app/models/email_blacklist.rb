class EmailBlacklist < ApplicationRecord
  belongs_to_creator

  validates_uniqueness_of :domain, case_sensitive: false, message: 'already exists'
  after_save :invalidate_cache
  after_destroy :invalidate_cache

  def self.is_banned?(email)
    domain = email.split('@').last.strip.downcase
    banned_domains = Cache.get('banned_emails', 1.hour) do
      all().map {|x| x.domain.strip.downcase}.flatten
    end
    banned_domains.count {|x| domain.end_with?(x)} > 0
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

  def invalidate_cache
    Cache.delete('banned_emails')
  end
end
