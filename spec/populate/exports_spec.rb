# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Exports, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(dir) }

  def column_type(table, column)
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT data_type FROM information_schema.columns WHERE table_schema = 'seed' AND table_name = '#{table}' AND column_name = '#{column}'
    SQL
  end

  it "loads an export into the seed schema with typed columns" do
    create(:tag, name: "dragon", category: 5, post_count: 12)
    create(:tag, name: "scalie", is_locked: true)
    write_export("tags", dir)

    expect { described_class.load!(tables: %w[tags], dir: dir) }.to output(/2 rows in/).to_stdout

    expect(seed_count("tags")).to eq(2)
    expect(column_type("tags", "id")).to eq("bigint")
    expect(column_type("tags", "category")).to eq("integer")
    expect(column_type("tags", "created_at")).to eq("timestamp without time zone")
    expect(column_type("tags", "is_locked")).to eq("boolean")
    expect(column_type("tags", "name")).to eq("text")
    expect(described_class.loaded?("tags")).to be(true)
    expect(described_class.loaded?("posts")).to be(false)
  end

  it "skips an unchanged file and reloads with force" do
    create(:tag)
    write_export("tags", dir)
    expect { described_class.load!(tables: %w[tags], dir: dir) }.to output(/1 rows in/).to_stdout

    expect { described_class.load!(tables: %w[tags], dir: dir) }.to output(/already loaded/).to_stdout
    expect { described_class.load!(tables: %w[tags], dir: dir, force: true) }.to output(/1 rows in/).to_stdout
  end

  it "rejects unknown tables and missing files" do
    expect { described_class.load!(tables: %w[users], dir: dir) }.to raise_error(ArgumentError, /unknown export tables: users/)
    expect { described_class.load!(tables: %w[tags], dir: dir) }.to raise_error(ArgumentError, /does not exist/)
  end

  it "moves a sequence past the highest id" do
    tag = create(:tag)
    ActiveRecord::Base.connection.execute("SELECT setval('tags_id_seq', 1, false)")

    described_class.bump_sequence!("tags")

    expect(ActiveRecord::Base.connection.select_value("SELECT nextval('tags_id_seq')").to_i).to eq(tag.id + 1)
  end

  it "knows whether a table can be loaded" do
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS seed.pools")
    expect(described_class.available?("pools", dir: dir)).to be(false)

    create(:pool)
    write_export("pools", dir)
    expect(described_class.available?("pools", dir: dir)).to be(true)
    expect { described_class.load!(tables: %w[pools], dir: dir, force: true) }.to output(/1 rows in/).to_stdout
    expect(described_class.available?("pools", dir: Dir.mktmpdir)).to be(true) # loaded beats missing file
  end
end
