# frozen_string_literal: true

require "rails_helper"

RSpec.describe ArtistsHelper do
  include_context "as admin"

  let!(:artist) { create(:artist) }

  describe "#link_to_artist" do
    it "returns an empty string for a blank name" do
      expect(helper.link_to_artist("")).to eq("")
    end

    it "links an existing artist to its short path" do
      expect(helper.link_to_artist(artist.name)).to include(%(href="/a/#{artist.name}"))
    end

    it "links an unknown name to the new artist form with a notice" do
      html = helper.link_to_artist("unknown_artist")
      expect(html).to include("/artists/new")
      expect(html).to include("new-artist")
    end
  end

  describe "#link_to_artists" do
    it "skips blank names" do
      html = helper.link_to_artists([artist.name, ""])
      expect(html).to eq(helper.link_to_artist(artist.name))
    end
  end
end
