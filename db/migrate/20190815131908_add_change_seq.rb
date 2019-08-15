class AddChangeSeq < ActiveRecord::Migration[5.2]
  def up
    execute "set statement_timeout = 0"
    add_column :posts, :change_seq, :bigserial, null: false
    add_index :posts, :change_seq, unique: true
    fields = %w[tag_string parent_id source approver_id rating description md5 is_deleted is_pending is_flagged is_rating_locked]
    fields += %w[is_status_locked is_note_locked bit_flags has_active_children last_noted_at]
    conditional = fields.map {|field| "NEW.#{field} != OLD.#{field}"}.join(' OR ')
    execute <<SQL
CREATE OR REPLACE FUNCTION posts_trigger_change_seq()
  RETURNS trigger AS
$BODY$
BEGIN
  IF #{conditional}
  THEN
     NEW.change_seq = nextval('public.posts_change_seq_seq');
  END IF;
  RETURN NEW;
END;
$BODY$ LANGUAGE 'plpgsql';
SQL
    execute "CREATE TRIGGER posts_update_change_seq BEFORE UPDATE ON posts FOR EACH ROW EXECUTE PROCEDURE posts_trigger_change_seq()"
  end

  def down
    execute "set statement_timeout = 0"
    execute "drop trigger posts_update_change_seq ON posts"
    remove_column :posts, :change_seq
    execute "drop function posts_trigger_change_seq"
  end
end
