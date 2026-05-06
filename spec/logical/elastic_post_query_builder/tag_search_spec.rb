# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "tag search" do
    describe "must tags" do
      it "adds a term clause to must for a plain positive tag" do
        expect(build_query("cute").must).to include({ term: { tags: "cute" } })
      end

      it "adds term clauses for multiple positive tags" do
        must = build_query("cute fluffy").must
        expect(must).to include({ term: { tags: "cute" } })
        expect(must).to include({ term: { tags: "fluffy" } })
      end
    end

    describe "must_not tags" do
      it "adds a term clause to must_not for a negated tag" do
        expect(build_query("-gross").must_not).to include({ term: { tags: "gross" } })
      end

      it "adds term clauses for multiple negated tags" do
        must_not = build_query("-gross -ugly").must_not
        expect(must_not).to include({ term: { tags: "gross" } })
        expect(must_not).to include({ term: { tags: "ugly" } })
      end
    end

    describe "should tags" do
      it "adds a term clause to should for a ~ tag" do
        expect(build_query("~fluffy").should).to include({ term: { tags: "fluffy" } })
      end

      it "adds term clauses for multiple ~ tags" do
        should_clauses = build_query("~fluffy ~soft").should
        expect(should_clauses).to include({ term: { tags: "fluffy" } })
        expect(should_clauses).to include({ term: { tags: "soft" } })
      end
    end

    describe "mixed polarities" do
      it "routes each tag to the correct array" do
        builder = build_query("cute -gross ~fluffy")
        expect(builder.must).to include({ term: { tags: "cute" } })
        expect(builder.must_not).to include({ term: { tags: "gross" } })
        expect(builder.should).to include({ term: { tags: "fluffy" } })
      end
    end

    describe "#add_tag_string_search_relation" do
      it "populates must, must_not, and should directly from a tags hash" do
        builder = build_query("")
        tags = {
          must: ["wolf"],
          must_not: ["cat"],
          should: ["dog"],
        }
        builder.add_tag_string_search_relation(tags)
        expect(builder.must).to include({ term: { tags: "wolf" } })
        expect(builder.must_not).to include({ term: { tags: "cat" } })
        expect(builder.should).to include({ term: { tags: "dog" } })
      end

      it "handles empty arrays without raising" do
        builder = build_query("")
        expect { builder.add_tag_string_search_relation({ must: [], must_not: [], should: [] }) }.not_to raise_error
      end
    end
  end
end
