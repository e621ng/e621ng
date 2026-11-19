# frozen_string_literal: true

require "csv"
require "zlib"

module Populate
  # Loads the public database exports (db/exports/*.csv.gz, written by DbExportJob)
  # into a `seed` staging schema so importers can select from them in SQL. See doc 44.
  module Exports
    SCHEMA = "seed"
    TABLES = %w[artists bulk_update_requests pools post_replacements post_versions posts tag_aliases tag_implications tags wiki_pages].freeze
    DEFAULT_TABLES = (TABLES - %w[post_versions]).freeze # post_versions is ~10 GB; opt in

    INDEXES = {
      "posts" => %w[md5 parent_id],
      "post_versions" => %w[post_id],
      "post_replacements" => %w[post_id],
    }.freeze

    # Column types are guessed from the CSV header name; anything else stays text.
    COLUMN_TYPES = [
      [/\A(id|.*_id)\z/, "bigint"],
      [/_at\z/, "timestamp"],
      [/\A(is_.*|.*_changed|processed)\z/, "boolean"],
      [/\A(.*_count|score|.*_score|.*_votes|version|change_seq|image_width|image_height|file_size|category|sequence_number)\z/, "integer"],
      [/\Aduration\z/, "double precision"],
    ].freeze

    module_function

    def default_dir
      Rails.root.join("db/exports").to_s
    end

    def file_for(table, dir = default_dir)
      File.join(dir, "#{table}.csv.gz")
    end

    def column_type(name)
      COLUMN_TYPES.find { |pattern, _| pattern.match?(name) }&.last || "text"
    end

    def connection
      ActiveRecord::Base.connection
    end

    def loaded?(table)
      connection.select_value("SELECT to_regclass('#{SCHEMA}.#{table}')::text").present?
    end

    # Loads whichever of the given tables are not in the staging schema yet.
    def ensure_loaded!(*tables, dir: default_dir)
      missing = tables.flatten.reject { |table| loaded?(table) }
      load!(tables: missing, dir: dir) if missing.any?
    end

    def load!(tables: DEFAULT_TABLES, dir: default_dir, force: false)
      unknown = tables - TABLES
      raise ArgumentError, "unknown export tables: #{unknown.join(', ')}" if unknown.any?

      connection.execute("CREATE SCHEMA IF NOT EXISTS #{SCHEMA}")
      connection.execute(<<~SQL.squish)
        CREATE TABLE IF NOT EXISTS #{SCHEMA}.loaded_files (
          name text PRIMARY KEY, size bigint NOT NULL, mtime timestamp NOT NULL,
          rows bigint NOT NULL, loaded_at timestamp NOT NULL
        )
      SQL

      tables.each { |table| load_table(table, dir, force) }
    end

    def load_table(table, dir, force)
      path = file_for(table, dir)
      raise ArgumentError, "#{path} does not exist" unless File.exist?(path)

      stat = File.stat(path)
      if !force && up_to_date?(table, stat)
        puts "* #{table}: already loaded, skipping (FORCE=1 to reload)"
        return
      end

      columns = CSV.parse_line(Zlib::GzipReader.open(path, &:gets).to_s.strip)
      raise ArgumentError, "#{path} has no header" if columns.blank?

      definitions = columns.map { |name| [name, column_type(name)] }
      puts "* #{table}: loading #{ActiveSupport::NumberHelper.number_to_human_size(stat.size)} from #{path}"
      puts "  columns: #{definitions.map { |name, type| "#{name} #{type}" }.join(', ')}"

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      target = "#{SCHEMA}.#{connection.quote_table_name(table)}"
      quoted_columns = columns.map { |name| connection.quote_column_name(name) }

      with_timeout_off do
        connection.execute("DROP TABLE IF EXISTS #{target}")
        connection.execute("CREATE TABLE #{target} (#{definitions.map { |name, type| "#{connection.quote_column_name(name)} #{type}" }.join(', ')})")
        copy_from_gzip(path, "COPY #{target} (#{quoted_columns.join(', ')}) FROM STDIN WITH (FORMAT csv, HEADER true)")

        (%w[id] + INDEXES.fetch(table, [])).each do |column|
          next unless columns.include?(column)
          connection.execute("CREATE INDEX ON #{target} (#{connection.quote_column_name(column)})")
        end
      end

      rows = connection.select_value("SELECT COUNT(*) FROM #{target}").to_i
      connection.execute(<<~SQL.squish)
        INSERT INTO #{SCHEMA}.loaded_files (name, size, mtime, rows, loaded_at)
        VALUES (#{connection.quote(table)}, #{stat.size}, #{connection.quote(stat.mtime.utc)}, #{rows}, #{connection.quote(Time.current.utc)})
        ON CONFLICT (name) DO UPDATE SET size = EXCLUDED.size, mtime = EXCLUDED.mtime, rows = EXCLUDED.rows, loaded_at = EXCLUDED.loaded_at
      SQL

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      puts "  #{rows} rows in #{elapsed.round(1)}s"
    end

    def up_to_date?(table, stat)
      return false unless loaded?(table)

      row = connection.select_one("SELECT size, mtime FROM #{SCHEMA}.loaded_files WHERE name = #{connection.quote(table)}")
      row.present? && row["size"].to_i == stat.size && row["mtime"].to_time.to_i == stat.mtime.to_i
    end

    def copy_from_gzip(path, sql)
      raw = connection.raw_connection
      raw.copy_data(sql) do
        Zlib::GzipReader.open(path) do |gz|
          while (chunk = gz.read(1 << 16))
            raw.put_copy_data(chunk)
          end
        end
      end
    end

    # The connection-level statement_timeout (config/database.yml) is far too short for a bulk load.
    def with_timeout_off
      connection.execute("SET statement_timeout = 0")
      yield
    ensure
      connection.execute("RESET statement_timeout")
    end

    # Moves the id sequence past the highest imported id so local inserts do not collide.
    def bump_sequence!(table, column: "id")
      quoted = connection.quote_table_name(table)
      connection.execute("SELECT setval(pg_get_serial_sequence('#{table}', '#{column}'), (SELECT COALESCE(MAX(#{column}), 0) + 1 FROM #{quoted}), false)")
    end
  end
end
