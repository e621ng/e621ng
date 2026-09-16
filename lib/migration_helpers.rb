# frozen_string_literal: true

# Shared helpers available to every migration (included into ActiveRecord::Migration -
# see config/application.rb). Keep additions here generic and reusable; a one-off schema
# change should just use `execute`/`change_column`/etc. directly in its own migration.
module MigrationHelpers
  # Reads the columns the live posts_trigger_change_seq() trigger currently checks, so a
  # migration can add or remove one without retyping the rest of the list.
  # @return [Array<String>] the posts columns the trigger currently compares
  def existing_change_seq_columns
    source = connection.select_one("SELECT prosrc FROM pg_proc WHERE proname = $1", nil, ["posts_trigger_change_seq"])&.[]("prosrc")

    return [] if source.nil?
    source.scan(/NEW\.(\w+) IS DISTINCT FROM OLD\.\1\b/).flatten
  end

  # @param columns [Array<String, Symbol>, nil] the exact set of columns to track; defaults
  #   to whatever posts_trigger_change_seq() currently tracks (see #existing_change_seq_columns)
  # @param add [Array<String, Symbol>] columns to add to `columns`
  # @param remove [Array<String, Symbol>] columns to drop from `columns`
  # @return [String] SQL that recreates posts_trigger_change_seq() with the resulting column set
  def update_change_seq_sql(columns = nil, add: [], remove: [])
    columns = (columns || existing_change_seq_columns).map(&:to_s)
    columns = (columns | Array(add).map(&:to_s)) - Array(remove).map(&:to_s)
    conditions = columns.map { |column| "NEW.#{column} IS DISTINCT FROM OLD.#{column}" }.join("\n        OR ")

    <<~SQL # rubocop:disable Rails/SquishedSQLHeredocs
      CREATE OR REPLACE FUNCTION public.posts_trigger_change_seq() RETURNS trigger
          LANGUAGE plpgsql
      AS $$
      BEGIN
          IF #{conditions}
          THEN
              NEW.change_seq = nextval('public.posts_change_seq_seq');
          END IF;
          RETURN NEW;
      END;
      $$;
    SQL
  end

  # Recreates posts_trigger_change_seq(), tracking `columns` (or, if omitted, whatever the
  # live function already tracks) plus `add` and minus `remove`.
  #
  # With `add`/`remove`, this is reversible on its own - the down direction just swaps them.
  # Passing an explicit `columns` list instead is a one-off rewrite, and not reversible.
  # @param columns [Array<String, Symbol>, nil] the exact set of columns to track; defaults
  #   to whatever posts_trigger_change_seq() currently tracks (see #existing_change_seq_columns)
  # @param add [Array<String, Symbol>] columns to add to `columns`
  # @param remove [Array<String, Symbol>] columns to drop from `columns`
  # @return [void]
  def update_change_seq(columns = nil, add: [], remove: [])
    if columns.present? && (add.present? || remove.present?)
      raise(ArgumentError, "columns cannot be provided alongside add: or remove:")
    end

    if add.blank? && remove.blank?
      execute(update_change_seq_sql(columns, add: [], remove: []))
    else
      reversible do |dir|
        dir.up   { execute(update_change_seq_sql(columns, add: add, remove: remove)) }
        dir.down { execute(update_change_seq_sql(columns, add: remove, remove: add)) }
      end
    end
  end
end

ActiveRecord::Migration.include(MigrationHelpers)
