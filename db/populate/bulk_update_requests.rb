# frozen_string_literal: true

module Populate
  class BulkUpdateRequests < Importer
    def call
      ensure_loaded!("bulk_update_requests")
      log "* Importing bulk update requests"

      stub_users_for("SELECT user_id FROM #{SEED}.bulk_update_requests UNION SELECT approver_id FROM #{SEED}.bulk_update_requests")

      # Forum topics and posts are not exported, so those references are dropped.
      requests = insert(<<~SQL.squish)
        INSERT INTO bulk_update_requests (id, user_id, forum_topic_id, script, status, created_at, updated_at, approver_id, forum_post_id, title)
        SELECT id, user_id, NULL, script, COALESCE(status, 'pending'), created_at, updated_at, approver_id, NULL, title
        FROM #{SEED}.bulk_update_requests
        ON CONFLICT DO NOTHING
      SQL
      log "  bulk update requests: #{requests} inserted"

      bump_sequences!("bulk_update_requests")
      requests
    end
  end
end
