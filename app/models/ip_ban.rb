# frozen_string_literal: true

class IpBan < ApplicationRecord
  belongs_to_creator
  validates :reason, :ip_addr, presence: true
  validates :ip_addr, uniqueness: true
  validate :validate_ip_addr
  after_create do |rec|
    ModAction.log(:ip_ban_create, { ip_addr: rec.subnetted_ip, reason: rec.reason })
  end
  after_destroy do |rec|
    ModAction.log(:ip_ban_delete, { ip_addr: rec.subnetted_ip, reason: rec.reason })
  end

  def self.is_banned?(ip_addr)
    where("ip_addr >>= ?", ip_addr).exists?
  end

  def self.search(params)
    q = super

    if params[:ip_addr].present?
      q = q.where("ip_addr >>= ?", params[:ip_addr])
    end

    q = q.where_user(:creator_id, :banner, params)

    q = q.attribute_matches(:reason, params[:reason])

    q.apply_basic_order(params)
  end

  def validate_ip_addr
    if ip_addr.blank?
      errors.add(:ip_addr, "is invalid")
    elsif ip_addr.ipv4? && ip_addr.prefix < 24
      errors.add(:ip_addr, "may not have a subnet bigger than /24")
    elsif ip_addr.ipv6? && ip_addr.prefix < 64
      errors.add(:ip_addr, "may not have a subnet bigger than /64")
    elsif ip_addr.private? || ip_addr.loopback? || ip_addr.link_local?
      errors.add(:ip_addr, "must be a public address")
    end
  end

  def has_subnet?
    (ip_addr.ipv4? && ip_addr.prefix < 32) || (ip_addr.ipv6? && ip_addr.prefix < 128)
  end

  def subnetted_ip
    str = ip_addr.to_s
    str += "/#{ip_addr.prefix}" if has_subnet?
    str
  end
end
