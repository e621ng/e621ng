#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

client = Post.document_store.client
conn = ApplicationRecord.connection

Post.find_in_batches(batch_size: 10_000) do |posts| # rubocop:disable Metrics/BlockLength
  post_ids = posts.map(&:id)
  post_ids_sql = post_ids.join(",")

  deletion_sql = <<-SQL # rubocop:disable Rails/SquishedSQLHeredocs
    SELECT pf.post_id, pf.created_at FROM
      (SELECT MAX(id) AS mid, post_id
       FROM post_flags
       WHERE post_id IN (#{post_ids_sql}) AND is_resolved = false AND is_deletion = true
       GROUP BY post_id) pfi
    INNER JOIN post_flags pf ON pf.id = pfi.mid;
  SQL

  flag_sql = <<-SQL # rubocop:disable Rails/SquishedSQLHeredocs
    SELECT pf.post_id, pf.creator_id, LOWER(pf.reason) AS reason, LOWER(pf.note) AS note, pf.created_at FROM
      (SELECT MAX(id) AS mid, post_id
       FROM post_flags
       WHERE post_id IN (#{post_ids_sql}) AND is_resolved = false AND is_deletion = false
       GROUP BY post_id) pfi
    INNER JOIN post_flags pf ON pf.id = pfi.mid;
  SQL

  deletions = conn.execute(deletion_sql).values
  flags = conn.execute(flag_sql).values

  deleted_at_by_post = deletions.to_h { |post_id, created_at| [post_id.to_i, created_at] } # rubocop:disable Style/HashTransformKeys
  flag_data_by_post = flags.to_h do |post_id, creator_id, reason, note, created_at|
    [post_id.to_i, { flagger: creator_id, flag_reason: reason, flag_note: note, flagged_at: created_at }]
  end

  body = post_ids.map do |post_id|
    flag_data = flag_data_by_post[post_id]
    {
      update: {
        _index: Post.document_store.index_name,
        _id: post_id,
        data: {
          doc: {
            deleted_at: deleted_at_by_post[post_id],
            flagged_at: flag_data&.dig(:flagged_at),
            flagger: flag_data&.dig(:flagger),
            flag_reason: flag_data&.dig(:flag_reason),
            flag_note: flag_data&.dig(:flag_note),
          },
        },
      },
    }
  end

  client.bulk(body: body, refresh: true)
  puts "updated through post ##{post_ids.max}"
end
