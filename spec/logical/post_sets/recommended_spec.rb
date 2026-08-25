# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSets::Recommended do
  include_context "as member"

  def make_post(character_tags: [], species_tags: [], known_artists: [])
    post = instance_double(Post, categorized_tags: {})
    allow(post).to receive(:tags_for_category) do |category|
      pairs = { "character" => character_tags, "species" => species_tags }
      (pairs[category] || []).map { |name| instance_double(Tag, name: name) }
    end
    allow(post).to receive(:known_artist_tags).and_return(known_artists.map { |name| instance_double(Tag, name: name) })
    post
  end

  describe ".available_for?" do
    context "tags mode" do
      it "is true when the post has character tags" do
        expect(described_class.available_for?(make_post(character_tags: %w[char_a]), :tags)).to be(true)
      end

      it "is true when the post has species tags" do
        expect(described_class.available_for?(make_post(species_tags: %w[spec_a]), :tags)).to be(true)
      end

      it "is false when the post has neither character nor species tags" do
        expect(described_class.available_for?(make_post(known_artists: %w[artist_a]), :tags)).to be(false)
      end
    end

    context "artist mode" do
      it "is true when the post has known artist tags" do
        expect(described_class.available_for?(make_post(known_artists: %w[artist_a]), :artist)).to be(true)
      end

      it "is false when the post has no known artist tags" do
        expect(described_class.available_for?(make_post(character_tags: %w[char_a]), :artist)).to be(false)
      end
    end

    it "is false when the mode is disabled in the configuration" do
      allow(Danbooru.config.custom_configuration).to receive(:post_recommendations_enabled?).and_return({ artist: true, tags: false })
      expect(described_class.available_for?(make_post(character_tags: %w[char_a]), :tags)).to be(false)
    end
  end

  describe "#post_ids" do
    it "returns an empty array without searching when the mode is unavailable" do
      allow(RecommendedQueryBuilder).to receive(:new)
      set = described_class.new(make_post, mode: :tags)
      expect(set.post_ids).to eq([])
      expect(RecommendedQueryBuilder).not_to have_received(:new)
    end

    it "delegates to the query builder when the mode is available" do
      response = instance_double(DocumentStore::Response, ids: [1, 2, 3])
      set = described_class.new(make_post(character_tags: %w[char_a]), mode: :tags)
      allow(set).to receive(:search_response).and_return(response)
      expect(set.post_ids).to eq([1, 2, 3])
    end
  end

  describe "mode normalization" do
    it "falls back to artist mode for unknown modes" do
      set = described_class.new(make_post(known_artists: %w[artist_a]), mode: :bogus)
      expect(set.mode).to eq(:artist)
    end
  end
end
