# frozen_string_literal: true

class CreateFavoriteEvents < ActiveRecord::Migration[8.1]
  def up
    Favorite.without_timeout do # rubocop:disable Metrics/BlockLength
      execute <<~SQL.squish
        CREATE SEQUENCE public.favorite_events_event_id_seq
      SQL

      execute <<~SQL.squish
        CREATE TABLE public.favorite_events (
          event_id    bigint                      NOT NULL DEFAULT nextval('public.favorite_events_event_id_seq'),
          favorite_id bigint                      NOT NULL,
          user_id     integer                     NOT NULL,
          post_id     integer                     NOT NULL,
          action      smallint                    NOT NULL,
          created_at  timestamp without time zone NOT NULL DEFAULT now(),
          PRIMARY KEY (event_id, created_at)
        ) PARTITION BY RANGE (created_at)
      SQL

      execute <<~SQL.squish
        ALTER SEQUENCE public.favorite_events_event_id_seq OWNED BY public.favorite_events.event_id
      SQL

      execute <<~SQL.squish
        CREATE INDEX ON public.favorite_events (created_at)
      SQL

      execute <<~SQL.squish
        CREATE INDEX ON public.favorite_events (user_id)
      SQL

      execute <<~SQL.squish
        CREATE INDEX ON public.favorite_events (post_id)
      SQL

      execute <<~SQL.squish
        CREATE OR REPLACE FUNCTION public.log_favorite_insert()
        RETURNS trigger AS $$
        BEGIN
          INSERT INTO public.favorite_events (favorite_id, user_id, post_id, action, created_at)
          VALUES (NEW.id, NEW.user_id, NEW.post_id, 1, NEW.created_at);
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
      SQL

      execute <<~SQL.squish
        CREATE OR REPLACE FUNCTION public.log_favorite_delete()
        RETURNS trigger AS $$
        BEGIN
          INSERT INTO public.favorite_events (favorite_id, user_id, post_id, action, created_at)
          VALUES (OLD.id, OLD.user_id, OLD.post_id, -1, now());
          RETURN OLD;
        END;
        $$ LANGUAGE plpgsql
      SQL

      execute <<~SQL.squish
        CREATE TRIGGER favorites_insert_event
        AFTER INSERT ON public.favorites
        FOR EACH ROW EXECUTE FUNCTION public.log_favorite_insert()
      SQL

      execute <<~SQL.squish
        CREATE TRIGGER favorites_delete_event
        AFTER DELETE ON public.favorites
        FOR EACH ROW EXECUTE FUNCTION public.log_favorite_delete()
      SQL
    end
  end

  def down
    Favorite.without_timeout do
      execute "DROP TRIGGER IF EXISTS favorites_delete_event ON public.favorites"
      execute "DROP TRIGGER IF EXISTS favorites_insert_event ON public.favorites"
      execute "DROP FUNCTION IF EXISTS public.log_favorite_delete()"
      execute "DROP FUNCTION IF EXISTS public.log_favorite_insert()"
      execute "DROP TABLE IF EXISTS public.favorite_events CASCADE"
    end
  end

  private

  def create_partition!(date)
    from = date.strftime("%Y-%m-%d")
    to   = (date + 1).strftime("%Y-%m-%d")
    name = "favorite_events_#{date.strftime('%Y_%m_%d')}"
    execute "CREATE TABLE IF NOT EXISTS public.#{name} PARTITION OF public.favorite_events FOR VALUES FROM ('#{from}') TO ('#{to}')"
  end
end
