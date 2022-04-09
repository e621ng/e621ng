class RemoveTestParser < ActiveRecord::Migration[6.1]
  def up
    execute "DROP TEXT SEARCH CONFIGURATION danbooru"
    execute "DROP TEXT SEARCH PARSER testparser"
    execute "DROP FUNCTION testprs_end"
    execute "DROP FUNCTION testprs_getlexeme"
    execute "DROP FUNCTION testprs_lextype"
    execute "DROP FUNCTION testprs_start"
    execute "DROP TRIGGER trigger_wiki_pages_on_update ON wiki_pages"
    execute "CREATE TRIGGER trigger_wiki_pages_on_update BEFORE INSERT OR UPDATE ON wiki_pages FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('body_index', 'pg_catalog.english', 'body', 'title')"
  end
end
