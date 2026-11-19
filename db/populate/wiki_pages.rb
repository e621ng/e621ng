# frozen_string_literal: true

module Populate
  class WikiPages < Importer
    def call
      ensure_loaded!("wiki_pages")
      log "* Importing wiki pages"

      stub_users_for("SELECT creator_id FROM #{SEED}.wiki_pages UNION SELECT updater_id FROM #{SEED}.wiki_pages")

      pages = insert(<<~SQL.squish)
        INSERT INTO wiki_pages (id, creator_id, title, body, is_locked, created_at, updated_at, updater_id, parent)
        SELECT id, creator_id, title, COALESCE(body, ''), COALESCE(is_locked, false), created_at, updated_at, updater_id, NULLIF(parent, '')
        FROM #{SEED}.wiki_pages
        ON CONFLICT DO NOTHING
      SQL
      log "  wiki pages: #{pages} inserted"

      bump_sequences!("wiki_pages")
      pages
    end
  end
end
