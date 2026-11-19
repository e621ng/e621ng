# frozen_string_literal: true

require "rails_helper"

# Tag-locked sites (doc 38 §10) require every post to carry the site's tags.
RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **)
  end

  describe "required tags" do
    it "adds one must clause per tag" do
      builder = build_query("", required_tags: %w[my_little_pony friendship_is_magic])
      expect(builder.must).to include({ term: { tags: "my_little_pony" } }, { term: { tags: "friendship_is_magic" } })
    end

    it "adds nothing for an empty list" do
      builder = build_query("", required_tags: [])
      expect(builder.must.select { |clause| clause.dig(:term, :tags) }).to be_empty
    end

    it "keeps the tags out of the parsed query" do
      builder = build_query("solo", required_tags: %w[my_little_pony])
      expect(builder.q.tag_count).to eq(1)
      expect(builder.must).to include({ term: { tags: "solo" } }, { term: { tags: "my_little_pony" } })
    end

    it "passes the tags on to grouped searches" do
      builder = build_query("( solo ~ duo )", required_tags: %w[my_little_pony])
      expect(builder.must.to_s.scan("my_little_pony").size).to be >= 1
    end

    context "with a tag-locked site profile" do
      include_context "with tag-locked site profile"

      it "reads the current site's tags by default" do
        builder = CurrentSite.with("mlp") { ElasticPostQueryBuilder.new("", resolve_aliases: false) }
        expect(builder.must).to include({ term: { tags: "my_little_pony" } })
      end

      it "requires nothing on the primary site" do
        builder = ElasticPostQueryBuilder.new("", resolve_aliases: false)
        expect(builder.must).not_to include({ term: { tags: "my_little_pony" } })
      end

      it "lets system searches opt out" do
        builder = CurrentSite.with("mlp") { ElasticPostQueryBuilder.new("", resolve_aliases: false, required_tags: []) }
        expect(builder.must).not_to include({ term: { tags: "my_little_pony" } })
      end
    end
  end
end
