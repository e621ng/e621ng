# frozen_string_literal: true

# Writes a db export the way DbExportJob does, from the test database into a temporary directory,
# so the populate importers can be exercised against real export shapes.
module PopulateExportsHelper
  def write_export(name, dir)
    sql = DbExportJob::EXPORTS.fetch(name)[:query].call
    path = File.join(dir, "#{name}.csv.gz")
    conn = ActiveRecord::Base.connection.raw_connection
    Zlib::GzipWriter.open(path) do |gz|
      conn.copy_data("COPY (#{sql}) TO STDOUT WITH CSV HEADER") do
        while (row = conn.get_copy_data)
          gz.write(row)
        end
      end
    end
    path
  end

  def seed_count(table)
    ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM seed.#{table}").to_i
  end
end

RSpec.configure do |config|
  config.include PopulateExportsHelper, :populate_exports
end
