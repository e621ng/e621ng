# frozen_string_literal: true

# Important:
#
# 140_backfill_legacy_null_columns.rb MUST be run before this migration,
# or the NOT NULL constraints will fail.
# (user_name_change_requests.user_id was already fixed manually in prod, 2026-08-12.)
#
# Restores the NOT NULL constraints that db/structure.sql already declares but prod
# relaxed years ago to fit pre-rewrite data (docs/export/from-db/DRIFT.md). On fresh
# installs every column is already NOT NULL and each step is a fast no-op.
#

class EnforceNotNullOnLegacyColumns < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  COLUMNS = {
    forum_posts: [:updater_id],
    news_updates: %i[creator_id updater_id],
    note_versions: [:updater_id],
    notes: [:creator_id],
    post_versions: [:updater_id],
    posts: %i[file_size image_height image_width is_status_locked uploader_id],
    tickets: %i[handler_id status],
    user_name_change_requests: [:user_id],
    user_statuses: %i[created_at updated_at],
    wiki_page_versions: [:updater_id],
  }.freeze

  def up
    ApplicationRecord.without_timeout do
      # Prod's tickets.status is nullable with no default; structure.sql already has
      # this default, so it only changes prod.
      change_column_default :tickets, :status, "pending"

      COLUMNS.each do |table, columns|
        columns.each { |column| enforce_not_null(table, column) }
      end
    end
  end

  def down
    # The columns were always NOT NULL in structure.sql; only prod drifted.
  end

  private

  # Unlike EnforcePostReplacementSequenceNumber, this touches huge tables, so a bare
  # change_column_null would hold an ACCESS EXCLUSIVE lock for a full-table scan.
  # Instead:
  # - add the equivalent CHECK constraint NOT VALID (instant)
  # - VALIDATE it (only takes a share lock)
  # - SET NOT NULL
  # Postgres sees the validated check and skips the scan — and drop the transient check.
  # Requires disable_ddl_transaction.
  def enforce_not_null(table, column)
    constraint = "#{table}_#{column}_not_null"
    add_check_constraint table, "#{column} IS NOT NULL", name: constraint, validate: false
    validate_check_constraint table, name: constraint
    change_column_null table, column, false
    remove_check_constraint table, name: constraint
  end
end
