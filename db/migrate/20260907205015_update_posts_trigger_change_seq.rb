# frozen_string_literal: true

# posts_trigger_change_seq() previously compared columns with `!=`, which is NULL-unsafe:
# a column changing into or out of NULL makes the whole OR-chain evaluate to NULL, so the IF
# is skipped and change_seq silently fails to bump. It had also drifted from the posts table -
# missing several columns added since, including uploader_id (reassigned on replacement
# approval), locked_tags, bg_color, video_samples and pool_ids, which all carry real,
# API-visible post content.
#
# Rebuilt from scratch with IS DISTINCT FROM and the current column list, via
# MigrationHelpers#update_change_seq (lib/migration_helpers.rb) so future column
# additions/removals can use `update_change_seq(add: ...)`/`(remove: ...)` instead of
# rewriting this list. See Post::CHANGE_SEQ_IGNORED for which posts columns are
# deliberately left out, and why - ChangeSeqSpec fails the build if a column is in neither
# place, or in both.
class UpdatePostsTriggerChangeSeq < ActiveRecord::Migration[8.1]
  TRACKED_COLUMNS = %w[
    source md5 rating
    is_note_locked is_rating_locked is_status_locked
    is_pending is_flagged is_deleted
    uploader_id approver_id parent_id
    tag_string locked_tags description bg_color
    last_noted_at has_active_children bit_flags
    video_samples pool_ids
  ].freeze

  def up
    update_change_seq(TRACKED_COLUMNS)
  end

  # Not reversible via update_change_seq: the old function compared with `!=`, which
  # update_change_seq intentionally cannot produce. Restored verbatim instead.
  def down
    execute(<<~SQL) # rubocop:disable Rails/SquishedSQLHeredocs
      CREATE OR REPLACE FUNCTION public.posts_trigger_change_seq() RETURNS trigger
          LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.tag_string != OLD.tag_string OR NEW.parent_id != OLD.parent_id OR NEW.source != OLD.source OR NEW.approver_id != OLD.approver_id OR NEW.rating != OLD.rating OR NEW.description != OLD.description OR NEW.md5 != OLD.md5 OR NEW.is_deleted != OLD.is_deleted OR NEW.is_pending != OLD.is_pending OR NEW.is_flagged != OLD.is_flagged OR NEW.is_rating_locked != OLD.is_rating_locked OR NEW.is_status_locked != OLD.is_status_locked OR NEW.is_note_locked != OLD.is_note_locked OR NEW.bit_flags != OLD.bit_flags OR NEW.has_active_children != OLD.has_active_children OR NEW.last_noted_at != OLD.last_noted_at
        THEN
          NEW.change_seq = nextval('public.posts_change_seq_seq');
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end
end
