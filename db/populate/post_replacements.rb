# frozen_string_literal: true

module Populate
  # Imports the approved replacements and original backups of imported posts. The export carries
  # neither storage ids nor sequence numbers, so both are derived; files are flat placeholders.
  class PostReplacements < Importer
    def call
      unless available?("post_replacements")
        log "* Skipping replacements: no post_replacements export in #{exports_dir}"
        return { replacements: 0 }
      end

      ensure_loaded!("posts", "post_replacements")
      log "* Importing post replacements"
      targets = "#{ImportedPosts.sql(options[:post_ids])} EXCEPT SELECT post_id FROM post_replacements2"

      stub_users_for(<<~SQL.squish)
        SELECT creator_id FROM #{SEED}.post_replacements WHERE post_id IN (#{targets})
        UNION SELECT approver_id FROM #{SEED}.post_replacements WHERE post_id IN (#{targets})
      SQL

      # One original per post at sequence 0 (the check constraint demands it); the rest numbered 1.. by id.
      ids = Exports.with_timeout_off do
        connection.select_values(<<~SQL.squish).map(&:to_i)
          WITH numbered AS (
            SELECT r.*, row_number() OVER (PARTITION BY r.post_id, r.status = 'original' ORDER BY r.id) AS rn
            FROM #{SEED}.post_replacements r WHERE r.post_id IN (#{targets})
          )
          INSERT INTO post_replacements2 (id, created_at, updated_at, post_id, creator_id, creator_ip_addr, approver_id, file_ext, file_size,
                                          image_height, image_width, md5, source, file_name, storage_id, status, reason, sequence_number)
          SELECT id, created_at, updated_at, post_id, creator_id, '#{LOCAL_IP}', approver_id, file_ext, COALESCE(file_size, 0),
                 COALESCE(image_height, 0), COALESCE(image_width, 0), md5, source, file_name, md5(id::text || md5), status, COALESCE(reason, ''),
                 CASE WHEN status = 'original' THEN 0 ELSE rn END
          FROM numbered
          WHERE status <> 'original' OR rn = 1
          ON CONFLICT DO NOTHING
          RETURNING id
        SQL
      end
      log "  replacements: #{ids.size} inserted"
      bump_sequences!("post_replacements2")

      write_files(ids) if options.fetch(:media, true)
      { replacements: ids.size }
    end

    private

    def write_files(ids)
      writer = Media::Placeholder.new(post_ids: [])
      PostReplacement.where(id: ids).find_each { |replacement| writer.write_replacement(replacement) }
    end
  end
end
