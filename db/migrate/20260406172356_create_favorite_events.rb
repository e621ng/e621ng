# frozen_string_literal: true

class CreateFavoriteEvents < ActiveRecord::Migration[8.1]
  def up
    Favorite.without_timeout do # rubocop:disable Metrics/BlockLength
      create_table :favorite_events, primary_key: :event_id do |t|
        t.bigint   :favorite_id
        t.integer  :user_id,    null: false
        t.integer  :post_id,    null: false
        t.integer  :action,     null: false, limit: 2
        t.datetime :created_at, null: false, default: -> { "now()" }
      end

      add_index :favorite_events, :created_at
      add_index :favorite_events, :user_id
      add_index :favorite_events, :post_id

      execute <<~SQL.squish
        CREATE OR REPLACE FUNCTION public.log_favorite_insert()
        RETURNS trigger AS $$
        BEGIN
          INSERT INTO public.favorite_events (favorite_id, user_id, post_id, action, created_at)
          VALUES (NEW.id, NEW.user_id, NEW.post_id, 1, NEW.created_at);
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
      SQL

      execute <<~SQL.squish
        CREATE OR REPLACE FUNCTION public.log_favorite_delete()
        RETURNS trigger AS $$
        BEGIN
          INSERT INTO public.favorite_events (favorite_id, user_id, post_id, action, created_at)
          VALUES (OLD.id, OLD.user_id, OLD.post_id, -1, now());
          RETURN OLD;
        END;
        $$ LANGUAGE plpgsql;
      SQL

      execute <<~SQL.squish
        CREATE TRIGGER favorites_insert_event
        AFTER INSERT ON public.favorites
        FOR EACH ROW EXECUTE FUNCTION public.log_favorite_insert();
      SQL

      execute <<~SQL.squish
        CREATE TRIGGER favorites_delete_event
        AFTER DELETE ON public.favorites
        FOR EACH ROW EXECUTE FUNCTION public.log_favorite_delete();
      SQL
    end
  end

  def down
    Favorite.without_timeout do
      execute "DROP TRIGGER IF EXISTS favorites_delete_event ON public.favorites"
      execute "DROP TRIGGER IF EXISTS favorites_insert_event ON public.favorites"
      execute "DROP FUNCTION IF EXISTS public.log_favorite_delete()"
      execute "DROP FUNCTION IF EXISTS public.log_favorite_insert()"
      drop_table :favorite_events
    end
  end
end
