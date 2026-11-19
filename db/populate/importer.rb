# frozen_string_literal: true

module Populate
  # Shared plumbing for generators that copy rows out of the seed schema.
  class Importer < Base
    SEED = Exports::SCHEMA

    private

    def exports_dir
      options.fetch(:dir, Exports.default_dir)
    end

    def ensure_loaded!(*tables)
      Exports.ensure_loaded!(*tables, dir: exports_dir)
    end

    def available?(table)
      Exports.available?(table, dir: exports_dir)
    end

    def connection
      ActiveRecord::Base.connection
    end

    # Runs an INSERT ... SELECT and returns the number of rows written.
    def insert(sql)
      Exports.with_timeout_off { connection.execute(sql).cmd_tuples }
    end

    def select_ids(sql)
      Exports.with_timeout_off { connection.select_values(sql).compact.map(&:to_i).uniq }
    end

    # Creates placeholder users for ids referenced by imported rows. `sql` selects the ids.
    def stub_users_for(sql)
      created = StubUsers.new(ids: select_ids(sql)).call
      log "  stub users: #{created} created"
    end

    def bump_sequences!(*tables)
      tables.each { |table| Exports.bump_sequence!(table) }
    end
  end
end
