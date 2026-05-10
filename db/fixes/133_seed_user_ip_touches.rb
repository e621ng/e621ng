# frozen_string_literal: true

# Seeds user_ip_touches and ip_addr_stats from the last 5 years of activity
# across all known IP-bearing source tables. Idempotent — safe to re-run.
# Records cursor progress per source after each batch so an interrupt resumes
# near where it left off rather than rewalking from id 0.
module Fixes
  class SeedUserIpTouches
    BATCH_SIZE = 1000

    SOURCES = [
      ["comment",            Comment,         :creator_id, :creator_ip_addr, :id],
      ["dmail",              Dmail,           :from_id,    :creator_ip_addr, :id],
      ["blip",               Blip,            :creator_id, :creator_ip_addr, :id],
      ["post_flag",          PostFlag,        :creator_id, :creator_ip_addr, :id],
      ["post",               Post,            :uploader_id, :uploader_ip_addr, :id],
      ["artist_version",     ArtistVersion,   :updater_id, :updater_ip_addr, :id],
      ["note_version",       NoteVersion,     :updater_id, :updater_ip_addr, :id],
      ["pool_version",       PoolVersion,     :updater_id, :updater_ip_addr, :id],
      ["post_version",       PostVersion,     :updater_id, :updater_ip_addr, :id],
      ["wiki_page_version",  WikiPageVersion, :updater_id, :updater_ip_addr, :id],
      ["login",              User,            :id,         :last_ip_addr,    :ts],
    ].freeze

    def self.run
      ApplicationRecord.connection.tap do
        SOURCES.each do |(source, klass, user_col, ip_col, mode)|
          process_source(source, klass, user_col, ip_col, mode)
        end
        puts "\nFinalizing ip_addr_stats..."
        finalize_ip_addr_stats
        puts "Done."
      end
    end

    def self.process_source(source, klass, user_col, ip_col, mode)
      cursor = UserIpTouchCursor.cursor_for(source)
      cutoff = cursor.cutoff_at
      total = if mode == :id
                klass.where("created_at >= ?", cutoff).where.not(ip_col => nil).count
              else
                klass.where("last_logged_in_at >= ?", cutoff).where.not(ip_col => nil).count
              end
      puts "[#{source}] #{total} rows to process"
      return if total.zero?

      processed = 0
      klass.without_timeout do
        loop do
          batch = next_batch(klass, user_col, ip_col, mode, cursor, cutoff)
          break if batch.empty?

          rows = batch.group_by { |(_id, uid, ip, _t)| [uid, ip] }.map do |(uid, ip), group|
            {
              user_id:      uid,
              ip_addr:      ip,
              source:       source,
              last_seen_at: group.map { |(_id, _u, _i, t)| t }.max,
              hit_count:    group.size,
            }
          end

          UserIpTouch.record_touches!(rows)

          last = batch.last
          if mode == :id
            cursor.advance!(last_processed_id: last[0])
          else
            cursor.advance!(last_processed_at: last[3])
          end

          processed += batch.size
          print "\r[#{source}] #{processed}/#{total}"
          break if batch.size < BATCH_SIZE
        end
      end
      puts ""
    end

    def self.next_batch(klass, user_col, ip_col, mode, cursor, cutoff)
      base = klass.where.not(ip_col => nil).where.not(user_col => nil)
      scope = case mode
              when :id
                base.where("created_at >= ?", cutoff)
                    .where("id > ?", cursor.last_processed_id || 0)
                    .order(:id).limit(BATCH_SIZE)
              when :ts
                anchor = cursor.last_processed_at || cutoff
                base.where("last_logged_in_at > ?", anchor)
                    .order(:last_logged_in_at).limit(BATCH_SIZE)
              end

      ts_col = mode == :ts ? :last_logged_in_at : :created_at
      scope.pluck(:id, user_col, ip_col, ts_col)
    end

    def self.finalize_ip_addr_stats
      ApplicationRecord.connection.execute(<<~SQL.squish)
        INSERT INTO ip_addr_stats (ip_addr, distinct_user_count, last_seen_at, created_at, updated_at)
        SELECT ip_addr, COUNT(DISTINCT user_id), MAX(last_seen_at), NOW(), NOW()
        FROM user_ip_touches
        GROUP BY ip_addr
        ON CONFLICT (ip_addr) DO UPDATE SET
          distinct_user_count = EXCLUDED.distinct_user_count,
          last_seen_at = EXCLUDED.last_seen_at,
          updated_at = NOW()
      SQL
    end

    private_class_method :process_source, :next_batch, :finalize_ip_addr_stats
  end
end

Fixes::SeedUserIpTouches.run
