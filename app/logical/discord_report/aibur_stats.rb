module DiscordReport
  class AiburStats < Base
    def webhook_url
      Danbooru.config.aibur_stats_discord_webhook_url
    end

    def report
      current_stats = stats
      previous_stats = Cache.redis.get("aibur_report:previous") || current_stats
      previous_stats = JSON.parse(previous_stats, symbolize_names: true) if previous_stats.is_a?(String)
      Cache.redis.set("aibur_report:previous", current_stats.to_json)

      alias_diff = current_stats[:aliases][:pending] - previous_stats[:aliases][:pending]
      implication_diff = current_stats[:implications][:pending] - previous_stats[:implications][:pending]
      bur_diff = current_stats[:burs][:pending] - previous_stats[:burs][:pending]
      total_handled = current_stats[:aliases][:handled] + current_stats[:implications][:handled] + current_stats[:burs][:handled]

      <<~REPORT.chomp
        AIBUR report for <t:#{Time.now.to_i}:D>
        Currently, there are:
        #{formatted_number(current_stats[:aliases][:pending])} pending aliases. That is #{more_fewer(alias_diff)} than the day before.
        #{formatted_number(current_stats[:implications][:pending])} pending implications. That is #{more_fewer(implication_diff)} than the day before.
        #{formatted_number(current_stats[:burs][:pending])} pending BURs. That is #{more_fewer(bur_diff)} than the day before. These pending BURs contain:
          #{formatted_number(current_stats[:burs][:details][:aliases])} aliases
          #{formatted_number(current_stats[:burs][:details][:implications])} implications
          #{formatted_number(current_stats[:burs][:details][:others])} other instructions

        In total, #{formatted_number(total_handled)} AIBURs were handled:
        Aliases: #{formatted_number(current_stats[:aliases][:handled])}
        Implications: #{formatted_number(current_stats[:implications][:handled])}
        BURs: #{formatted_number(current_stats[:burs][:handled])}
      REPORT
    end

    def stats
      {
        aliases: counting(TagAlias),
        implications: counting(TagImplication),
        burs: {
          **counting(BulkUpdateRequest),
          details: bur_details,
        },
      }
    end

    def counting(clazz)
      {
        pending: clazz.pending.count,
        handled: clazz.where(status: %w[approved active processing queued deleted]).where("created_at >= ? AND forum_topic_id IS NOT NULL", 1.day.ago).count,
      }
    end

    def bur_details
      BulkUpdateRequest.pending.find_each.each_with_object({ aliases: 0, implications: 0, others: 0 }) do |bur, result|
        BulkUpdateRequestImporter.tokenize(bur.script).map(&:first).each do |type|
          case type
          when :create_alias
            result[:aliases] += 1
          when :create_implication
            result[:implications] += 1
          else
            result[:others] += 1
          end
        end
      end
    end
  end
end
