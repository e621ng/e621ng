# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Artist::TagMethods                                  #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  before { skip "Artist model not available in this fork" unless Rails.application.routes.url_helpers.respond_to?(:artist_urls_path) }

  include_context "as admin"

  def make_artist(overrides = {})
    create(:artist, **overrides)
  end

  # -------------------------------------------------------------------------
  # #categorize_tag (after_save)
  # -------------------------------------------------------------------------
  describe "#categorize_tag" do
    it "creates an artist-category Tag when the artist is created" do
      name = generate(:artist_name)
      expect { make_artist(name: name) }.to change(Tag, :count).by_at_least(1)
      tag = Tag.find_by(name: name)
      expect(tag).to be_present
      expect(tag.category).to eq(Tag.categories.artist)
    end

    it "does not create a duplicate tag when one already exists" do
      name = generate(:artist_name)
      create(:artist_tag, name: name)
      expect { make_artist(name: name) }.not_to(change { Tag.where(name: name).count })
    end

    it "creates a new artist tag when the artist is renamed" do
      artist = make_artist
      new_name = "#{artist.name}_renamed"
      expect { artist.update!(name: new_name) }.to change(Tag, :count).by_at_least(1)
      expect(Tag.find_by(name: new_name)).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # #category_id
  # -------------------------------------------------------------------------
  describe "#category_id" do
    it "returns the artist category ID when the underlying tag exists" do
      artist = make_artist
      # categorize_tag has already fired; reload association
      artist.reload
      expect(artist.category_id).to eq(Tag.categories.artist)
    end
  end
end
