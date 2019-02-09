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

  def invalidate_cache
    Cache.delete('banned_emails')
  end
end
