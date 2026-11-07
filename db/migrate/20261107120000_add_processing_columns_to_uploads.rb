# frozen_string_literal: true

class AddProcessingColumnsToUploads < ActiveRecord::Migration[8.1]
  def up
    change_table :uploads, bulk: true do |t|
      t.text :processing_step
      t.text :error_message
      t.text :warnings
      t.boolean :is_animated, null: false, default: false
      t.decimal :duration
      t.boolean :has_sound, null: false, default: false
      t.text :locked_tags
      t.boolean :locked_rating, null: false, default: false
      t.boolean :as_pending, null: false, default: false
      t.text :submitted_tag_string
      t.timestamp :processing_started_at
      t.timestamp :processed_at
      t.timestamp :requeued_at
    end

    # Old free-text statuses: "error: ActiveRecord::RecordInvalid - Validation failed: Md5 duplicate: 123"
    # becomes "duplicate: 123"; every other "error: ..." becomes "failed" with the text in error_message.
    execute <<~SQL.squish
      UPDATE uploads
      SET error_message = status,
          status = 'duplicate: ' || substring(status from 'duplicate: (\\d+)')
      WHERE status LIKE 'error:%' AND status ~ 'duplicate: \\d+'
    SQL
    execute <<~SQL.squish
      UPDATE uploads
      SET error_message = regexp_replace(substring(status from 8), 'DETAIL:.*$', '...'),
          status = 'failed'
      WHERE status LIKE 'error:%'
    SQL
  end

  def down
    execute "UPDATE uploads SET status = 'error: ' || COALESCE(error_message, '') WHERE status = 'failed'"

    change_table :uploads, bulk: true do |t|
      t.remove :processing_step, :error_message, :warnings, :is_animated, :duration, :has_sound,
               :locked_tags, :locked_rating, :as_pending, :submitted_tag_string,
               :processing_started_at, :processed_at, :requeued_at
    end
  end
end
