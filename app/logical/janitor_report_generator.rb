class JanitorReportGenerator
  extend ActiveSupport::NumberHelper

  def self.run!
    return if Danbooru.config.janitor_reports_discord_webhook_url.blank?

    current_stats = stats
    previous_queue_size = Cache.redis.get("janitor_reports:previous_queue_size") || current_stats[:queue_size]
    Cache.redis.set("janitor_reports:previous_queue_size", current_stats[:queue_size])

    diff = current_stats[:queue_size] - previous_queue_size.to_i
    content = <<~REPORT.chomp
      Janitor report for <t:#{Time.now.to_i}:D>
      Currently, there are #{number_to_delimited(current_stats[:queue_size])} pending posts. There were #{number_to_delimited(previous_queue_size)} pending posts yesterday.
      That is #{number_to_delimited(diff)} #{diff >= 0 ? 'more' : 'less'} than the day before.

      #{number_to_delimited(current_stats[:posts])} posts were added yesterday.

      #{number_to_delimited(current_stats[:approvals] + current_stats[:deletions][:total])} posts were processed.
      Approvals: #{number_to_delimited(current_stats[:approvals])}
      Deletions: #{number_to_delimited(current_stats[:deletions][:total])} (#{number_to_delimited(current_stats[:deletions][:automod] - current_stats[:deletions][:takedowns])} automated, #{number_to_delimited(current_stats[:deletions][:takedowns])} takedown, #{number_to_delimited(current_stats[:deletions][:total] - current_stats[:deletions][:automod])} manual)
    REPORT

    HTTParty.post(
      Danbooru.config.janitor_reports_discord_webhook_url,
      body: {
        content: content,
        flags: 4096,
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  def self.stats
    deletions = PostFlag.where(is_deletion: true).where("created_at >= ?", 1.day.ago)
    {
      queue_size: Post.pending.count,
      deletions: {
        total: deletions.count,
        automod: deletions.where(creator_id: User.system.id).count,
        takedowns: deletions.where("reason LIKE ?", "takedown #%").count,
      },
      approvals: PostApproval.where("created_at >= ?", 1.day.ago).count,
      posts: Post.where("created_at >= ? ", 1.day.ago).count,
    }
  end
end
