CREATE OR REPLACE FUNCTION public.posts_trigger_change_seq()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.tag_string != OLD.tag_string OR NEW.parent_id != OLD.parent_id OR NEW.source != OLD.source OR NEW.approver_id != OLD.approver_id OR NEW.rating != OLD.rating OR NEW.description != OLD.description OR NEW.md5 != OLD.md5 OR NEW.is_deleted != OLD.is_deleted OR NEW.is_pending != OLD.is_pending OR NEW.is_flagged != OLD.is_flagged OR NEW.is_rating_locked != OLD.is_rating_locked OR NEW.is_status_locked != OLD.is_status_locked OR NEW.is_note_locked != OLD.is_note_locked OR NEW.bit_flags != OLD.bit_flags OR NEW.has_active_children != OLD.has_active_children OR NEW.last_noted_at != OLD.last_noted_at
  THEN
     NEW.change_seq = nextval('public.posts_change_seq_seq');
  END IF;
  RETURN NEW;
END;
$function$
 ;

CREATE TRIGGER trigger_blips_on_update BEFORE INSERT OR UPDATE ON blips FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('body_index', 'pg_catalog.english', 'body');
CREATE TRIGGER trigger_comments_on_update BEFORE INSERT OR UPDATE ON comments FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('body_index', 'pg_catalog.english', 'body');
CREATE TRIGGER trigger_forum_posts_on_update BEFORE INSERT OR UPDATE ON forum_posts FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('text_index', 'pg_catalog.english', 'body');
DROP TRIGGER trg_note_search_update ON public.notes;
CREATE TRIGGER trigger_notes_on_update BEFORE INSERT OR UPDATE ON notes FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('body_index', 'pg_catalog.english', 'body');
CREATE TRIGGER posts_update_change_seq BEFORE UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION posts_trigger_change_seq();
CREATE TRIGGER trigger_posts_on_tag_index_update BEFORE INSERT OR UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('tag_index', 'public.danbooru', 'tag_string', 'fav_string', 'pool_string');
DROP TRIGGER trg_wiki_page_search_update ON public.wiki_pages;
CREATE TRIGGER trigger_wiki_pages_on_update BEFORE INSERT OR UPDATE ON wiki_pages FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('body_index', 'public.danbooru', 'body', 'title');
