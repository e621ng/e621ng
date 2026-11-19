# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Artists, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(dir) }

  it "imports artists and rebuilds their urls" do
    artist = create(:artist, name: "wolfy", other_names: %w[wolfie], url_string: "https://Example.com/wolfy/ -https://old.example.com/wolfy")
    artist.update_columns(creator_id: 777_777)
    write_export("artists", dir)
    ArtistUrl.delete_all
    Artist.delete_all

    result = nil
    expect { result = described_class.new(dir: dir).call }.to output(/artist urls: 2 inserted/).to_stdout

    expect(result).to eq(artists: 1, urls: 2)
    imported = Artist.find(artist.id)
    expect(imported).to have_attributes(name: "wolfy", other_names: %w[wolfie], creator_id: 777_777)
    expect(imported.urls.map { |u| [u.url, u.normalized_url, u.is_active] }).to contain_exactly(
      ["https://Example.com/wolfy/", "http://example.com/wolfy/", true],
      ["https://old.example.com/wolfy", "http://old.example.com/wolfy/", false],
    )
    expect(User.find(777_777).name).to eq("user_777777")
    expect { expect(described_class.new(dir: dir).call).to eq(artists: 0, urls: 0) }.to output.to_stdout
  end
end
