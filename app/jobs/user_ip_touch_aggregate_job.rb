# frozen_string_literal: true

class UserIpTouchAggregateJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 5000

  # Mapping of source name -> [klass, user_column, ip_column, mode]
  # mode: :id  -> append-only, paginate by id > last_processed_id
  #       :ts  -> updated-in-place (users.last_ip_addr), paginate by last_logged_in_at > last_processed_at
  SOURCES = [
    ["comment",            "Comment",          :creator_id, :creator_ip_addr, :id],
    ["dmail",              "Dmail",            :from_id,    :creator_ip_addr, :id],
    ["blip",               "Blip",             :creator_id, :creator_ip_addr, :id],
    ["post_flag",          "PostFlag",         :creator_id, :creator_ip_addr, :id],
    ["post",               "Post",             :uploader_id, :uploader_ip_addr, :id],
    ["artist_version",     "ArtistVersion",    :updater_id, :updater_ip_addr, :id],
    ["note_version",       "NoteVersion",      :updater_id, :updater_ip_addr, :id],
    ["pool_version",       "PoolVersion",      :updater_id, :updater_ip_addr, :id],
    ["post_version",       "PostVersion",      :updater_id, :updater_ip_addr, :id],
    ["wiki_page_version",  "WikiPageVersion",  :updater_id, :updater_ip_addr, :id],
    ["login",              "User",             :id,         :last_ip_addr,    :ts],
  ].freeze

  def perform
    SOURCES.each do |(source, klass_name, user_col, ip_col, mode)|
      process_source!(source, klass_name.constantize, user_col, ip_col, mode)
    end
  end

  private

  def process_source!(source, klass, user_col, ip_col, mode)
    cursor = UserIpTouchCursor.cursor_for(source)
    cutoff = cursor.cutoff_at
    processed = 0

    loop do
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

      batch = scope.pluck(:id, user_col, ip_col, mode == :ts ? :last_logged_in_at : :created_at)
      break if batch.empty?

      rows = batch.group_by { |(_id, uid, ip, _t)| [uid, ip] }.map do |(uid, ip), group|
        last_seen = group.map { |(_id, _u, _i, t)| t }.max
        {
          user_id:      uid,
          ip_addr:      ip,
          source:       source,
          last_seen_at: last_seen,
          hit_count:    group.size,
        }
      end

      UserIpTouch.record_touches!(rows)
      IpAddrStat.recompute_for!(rows.map { |r| r[:ip_addr] }.uniq)

      last = batch.last
      if mode == :id
        cursor.advance!(last_processed_id: last[0])
      else
        cursor.advance!(last_processed_at: last[3])
      end

      processed += batch.size
      break if batch.size < BATCH_SIZE
    end

    Rails.logger.info("UserIpTouchAggregateJob[#{source}]: processed #{processed} rows") if processed.positive?
  end
end
