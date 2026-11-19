# frozen_string_literal: true

module Populate
  # Imports artists and rebuilds their artist_urls from the export's space-joined URL columns.
  class Artists < Importer
    BATCH_SIZE = 2000

    def call
      ensure_loaded!("artists")
      log "* Importing artists"

      stub_users_for("SELECT creator_id FROM #{SEED}.artists UNION SELECT linked_user_id FROM #{SEED}.artists")

      inserted_ids = Exports.with_timeout_off do
        connection.select_values(<<~SQL.squish).map(&:to_i)
          INSERT INTO artists (id, name, creator_id, is_active, group_name, created_at, updated_at, other_names, linked_user_id, is_locked)
          SELECT id, name, creator_id, COALESCE(is_active, true), COALESCE(group_name, ''), created_at, updated_at,
                 COALESCE(other_names, '{}')::text[], linked_user_id, COALESCE(is_locked, false)
          FROM #{SEED}.artists
          ON CONFLICT DO NOTHING
          RETURNING id
        SQL
      end
      log "  artists: #{inserted_ids.size} inserted"

      urls = 0
      inserted_ids.each_slice(BATCH_SIZE) do |batch|
        rows = url_rows(batch)
        ArtistUrl.insert_all(rows) if rows.any?
        urls += rows.size
      end
      log "  artist urls: #{urls} inserted"

      bump_sequences!("artists", "artist_urls")
      { artists: inserted_ids.size, urls: urls }
    end

    private

    def url_rows(artist_ids)
      now = Time.current
      sql = "SELECT id, active_urls, inactive_urls, created_at, updated_at FROM #{SEED}.artists WHERE id IN (#{artist_ids.join(',')})"
      connection.select_all(sql).flat_map do |artist|
        { true => artist["active_urls"], false => artist["inactive_urls"] }.flat_map do |is_active, joined|
          joined.to_s.split.uniq.map do |url|
            {
              artist_id: artist["id"],
              url: url,
              normalized_url: ArtistUrl.normalize(url),
              is_active: is_active,
              created_at: artist["created_at"] || now,
              updated_at: artist["updated_at"] || now,
            }
          end
        end
      end
    end
  end
end
