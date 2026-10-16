# frozen_string_literal: true

require "rails_helper"

# Tests the `allow_wildcard_tags` parse option. Saved-search contexts parse with it disabled:
# wildcard expansion snapshots the current top matching tags, so stored queries containing one
# would silently change meaning between evaluations.

RSpec.describe TagQuery do
  include_context "as member"

  describe "allow_wildcard_tags: true (default)" do
    it "expands must-position wildcards into should clauses" do
      tq = TagQuery.new("fox_*")
      expect(tq[:tags][:should]).not_to be_empty
    end

    it "expands must_not-position wildcards" do
      tq = TagQuery.new("-fox_*")
      expect(tq[:tags][:must_not]).not_to be_empty
    end
  end

  describe "allow_wildcard_tags: false" do
    it "raises InvalidTagError for a must-position wildcard" do
      expect { TagQuery.new("fox_*", allow_wildcard_tags: false) }.to raise_error(TagQuery::InvalidTagError, /wildcard/)
    end

    it "raises InvalidTagError for a must_not-position wildcard" do
      expect { TagQuery.new("-fox_*", allow_wildcard_tags: false) }.to raise_error(TagQuery::InvalidTagError, /wildcard/)
    end

    it "raises for a wildcard inside a group when groups are processed" do
      expect { TagQuery.new("( fox_* )", allow_wildcard_tags: false, process_groups: true) }.to raise_error(TagQuery::InvalidTagError)
    end

    it "does not expand the wildcard before raising" do
      allow(Tag).to receive(:name_matches)
      expect { TagQuery.new("fox_*", allow_wildcard_tags: false) }.to raise_error(TagQuery::InvalidTagError)
      expect(Tag).not_to have_received(:name_matches)
    end

    it "still allows wildcard-value metatags" do
      tq = TagQuery.new("source:*example* fox", allow_wildcard_tags: false)
      expect(tq[:sources]).to be_present
      expect(tq[:tags][:must]).to include("fox")
    end

    it "still allows plain tags" do
      tq = TagQuery.new("fox cat", allow_wildcard_tags: false)
      expect(tq[:tags][:must]).to match_array(%w[fox cat])
    end
  end

  describe "propagation through ElasticPostQueryBuilder string-group re-parses" do
    it "raises when a string group contains a wildcard" do
      expect do
        ElasticPostQueryBuilder.new("( fox_* ) cat", allow_wildcard_tags: false)
      end.to raise_error(TagQuery::InvalidTagError)
    end

    it "builds fine without the flag" do
      expect { ElasticPostQueryBuilder.new("( fox_* ) cat") }.not_to raise_error
    end
  end
end
