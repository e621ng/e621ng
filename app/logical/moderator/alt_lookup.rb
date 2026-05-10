# frozen_string_literal: true

module Moderator
  class AltLookup
    RESULT_CAP = 100

    def initialize(user)
      @user = user
    end

    def execute
      return [] unless Moderator::AltDetection.enabled?
      return [] if @user.blank?

      target_ips = UserIpTouch.where(user_id: @user.id).distinct.pluck(:ip_addr)
      return [] if target_ips.empty?

      cgnat_max = Moderator::AltDetection.cgnat_threshold
      eligible_ips = IpAddrStat.where(ip_addr: target_ips)
                               .where("distinct_user_count <= ?", cgnat_max)
                               .pluck(:ip_addr)
      return [] if eligible_ips.empty?

      rows = UserIpTouch
               .where(ip_addr: eligible_ips)
               .where.not(user_id: @user.id)
               .joins("JOIN ip_addr_stats USING (ip_addr)")
               .group("user_ip_touches.user_id")
               .pluck(
                 "user_ip_touches.user_id",
                 Arel.sql("SUM(1.0 / (1 + LN(GREATEST(ip_addr_stats.distinct_user_count, 2))))"),
                 Arel.sql("MAX(user_ip_touches.last_seen_at)"),
               )

      scored = rows.filter_map do |user_id, score, last_at|
        score_f = score.to_f
        badge = Moderator::AltDetection.score_to_badge(score_f)
        next unless badge
        { user_id: user_id, badge: badge, last_overlap_on: last_at.to_date, _score: score_f }
      end

      scored.sort_by { |r| -r[:_score] }
            .first(RESULT_CAP)
            .each { |r| r.delete(:_score) }
    end
  end
end
