# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecommendedQueryBuilder do
  include_context "as member"

  def make_post(**opts)
    id             = opts.fetch(:id, 42)
    known_artists  = opts.fetch(:known_artists, [])
    pool_ids       = opts.fetch(:pool_ids, [])
    character_tags = opts.fetch(:character_tags, [])
    copyright_tags = opts.fetch(:copyright_tags, [])
    species_tags   = opts.fetch(:species_tags, [])

    post = instance_double(Post, id: id)
    allow(post).to receive_messages(
      known_artist_tags: known_artists.map { |n| instance_double(Tag, name: n) },
      pool_ids: pool_ids,
    )
    allow(post).to receive(:tags_for_category) do |category|
      pairs = { "character" => character_tags, "copyright" => copyright_tags, "species" => species_tags }
      (pairs[category] || []).map { |name, count| instance_double(Tag, name: name, post_count: count) }
    end
    post
  end

  def build_for(post)
    RecommendedQueryBuilder.new(post)
  end

  describe "constants" do
    it "CHARACTER_WEIGHT is 2.0" do
      expect(described_class::CHARACTER_WEIGHT).to eq(2.0)
    end

    it "COPYRIGHT_WEIGHT is 1.5" do
      expect(described_class::COPYRIGHT_WEIGHT).to eq(1.5)
    end

    it "SPECIES_WEIGHT is 1.25" do
      expect(described_class::SPECIES_WEIGHT).to eq(1.25)
    end
  end

  describe "exclusion query" do
    let(:post) { make_post(id: 99) }
    let(:builder) { build_for(post) }

    it "excludes the post itself from results" do
      expect(builder.must_not).to include({ term: { id: 99 } })
    end

    it "excludes posts that are children of the post" do
      expect(builder.must_not).to include({ term: { parent: 99 } })
    end

    it "uses score-based ordering for random results" do
      expect(builder.order).to eq([{ _score: :desc }])
    end
  end

  describe "artist tags" do
    it "adds each known artist tag as a should term" do
      post = make_post(known_artists: %w[artist_a artist_b])
      builder = build_for(post)
      expect(builder.should).to include({ term: { tags: "artist_a" } })
      expect(builder.should).to include({ term: { tags: "artist_b" } })
    end

    it "adds no artist should terms when the post has no known artist tags" do
      builder = build_for(make_post(known_artists: []))
      artist_terms = builder.should.select { |clause| clause[:term]&.key?(:tags) }
      expect(artist_terms).to be_empty
    end

    it "adds at most 10 artist should terms when the post has more than 10 known artists" do
      artists = (1..15).map { |n| "artist_#{n}" }
      builder = build_for(make_post(known_artists: artists))
      artist_terms = builder.should.select { |clause| clause[:term]&.key?(:tags) }
      expect(artist_terms.size).to eq(10)
    end

    it "selects the alphabetically first 10 artist names when more than 10 are present" do
      artists = (1..15).map { |n| format("artist_%02d", n) }
      builder = build_for(make_post(known_artists: artists.shuffle))
      artist_terms = builder.should.select { |clause| clause[:term]&.key?(:tags) }
      expect(artist_terms.map { |c| c[:term][:tags] }).to match_array(artists.first(10))
    end
  end

  describe "pool exclusion" do
    it "adds a must_not terms clause for the post's pool ids" do
      builder = build_for(make_post(pool_ids: [10, 20]))
      expect(builder.must_not).to include({ terms: { pools: [10, 20] } })
    end

    it "does not add a pool must_not clause when the post has no pools" do
      builder = build_for(make_post(pool_ids: []))
      pool_clauses = builder.must_not.select { |clause| clause[:terms]&.key?(:pools) }
      expect(pool_clauses).to be_empty
    end
  end

  describe "function_score" do
    let(:post) { make_post(id: 7) }
    let(:function_score) { build_for(post).instance_variable_get(:@function_score) }

    it "uses sum score mode" do
      expect(function_score[:score_mode]).to eq(:sum)
    end

    it "uses replace boost mode" do
      expect(function_score[:boost_mode]).to eq(:replace)
    end

    it "always includes a random_score function seeded with the post id" do
      expect(function_score[:functions]).to include({ random_score: { seed: 7, field: "id" } })
    end

    context "when the post has no character, copyright, or species tags" do
      it "functions contains only the random_score entry" do
        expect(function_score[:functions].size).to eq(1)
      end
    end

    context "when the post has character tags" do
      let(:post) { make_post(character_tags: [["char_a", 1], ["char_b", 2]]) }

      it "includes a character weight function covering those tags" do
        char_fn = function_score[:functions].find { |f| f[:weight] == described_class::CHARACTER_WEIGHT }
        expect(char_fn).to be_present
        expect(char_fn[:filter][:terms][:tags]).to include("char_a", "char_b")
      end
    end

    context "when the post has no character tags" do
      it "does not include a character weight function" do
        char_fn = function_score[:functions].find { |f| f[:weight] == described_class::CHARACTER_WEIGHT }
        expect(char_fn).to be_nil
      end
    end

    context "when the post has copyright tags" do
      let(:post) { make_post(copyright_tags: [["copy_a", 1]]) }

      it "includes a copyright weight function covering those tags" do
        copy_fn = function_score[:functions].find { |f| f[:weight] == described_class::COPYRIGHT_WEIGHT }
        expect(copy_fn).to be_present
        expect(copy_fn[:filter][:terms][:tags]).to include("copy_a")
      end
    end

    context "when the post has no copyright tags" do
      it "does not include a copyright weight function" do
        copy_fn = function_score[:functions].find { |f| f[:weight] == described_class::COPYRIGHT_WEIGHT }
        expect(copy_fn).to be_nil
      end
    end

    context "when the post has species tags" do
      let(:post) { make_post(species_tags: [["spec_a", 1]]) }

      it "includes a species weight function covering those tags" do
        spec_fn = function_score[:functions].find { |f| f[:weight] == described_class::SPECIES_WEIGHT }
        expect(spec_fn).to be_present
        expect(spec_fn[:filter][:terms][:tags]).to include("spec_a")
      end
    end

    context "when the post has no species tags" do
      it "does not include a species weight function" do
        spec_fn = function_score[:functions].find { |f| f[:weight] == described_class::SPECIES_WEIGHT }
        expect(spec_fn).to be_nil
      end
    end

    context "when the post has all three tag categories" do
      let(:post) do
        make_post(
          character_tags: [["char_a", 1]],
          copyright_tags: [["copy_a", 1]],
          species_tags: [["spec_a", 1]],
        )
      end

      it "functions contains 4 entries: random_score plus one per category" do
        expect(function_score[:functions].size).to eq(4)
      end
    end
  end

  describe "tag selection (min_by post_count)" do
    it "selects the 10 character tags with the lowest post_count when more than 10 are present" do
      tags = (1..12).map { |n| ["char_#{n}", n * 10] } # post_counts 10, 20, ..., 120
      function_score = build_for(make_post(character_tags: tags)).instance_variable_get(:@function_score)
      selected = function_score[:functions].find { |f| f[:weight] == described_class::CHARACTER_WEIGHT }[:filter][:terms][:tags]
      expect(selected.size).to eq(10)
      expect(selected).not_to include("char_11", "char_12") # highest post_counts excluded
    end

    it "selects the 10 copyright tags with the lowest post_count when more than 10 are present" do
      tags = (1..12).map { |n| ["copy_#{n}", n * 10] }
      function_score = build_for(make_post(copyright_tags: tags)).instance_variable_get(:@function_score)
      selected = function_score[:functions].find { |f| f[:weight] == described_class::COPYRIGHT_WEIGHT }[:filter][:terms][:tags]
      expect(selected.size).to eq(10)
      expect(selected).not_to include("copy_11", "copy_12")
    end

    it "selects the 10 species tags with the lowest post_count when more than 10 are present" do
      tags = (1..12).map { |n| ["spec_#{n}", n * 10] }
      function_score = build_for(make_post(species_tags: tags)).instance_variable_get(:@function_score)
      selected = function_score[:functions].find { |f| f[:weight] == described_class::SPECIES_WEIGHT }[:filter][:terms][:tags]
      expect(selected.size).to eq(10)
      expect(selected).not_to include("spec_11", "spec_12")
    end
  end
end
