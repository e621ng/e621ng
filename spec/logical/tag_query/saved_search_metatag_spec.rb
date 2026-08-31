# frozen_string_literal: true

require "rails_helper"

# Tests the `search:<name-or-id>` metatag: resolves the current user's saved search and splices
# its stored query into the surrounding search as a group. Resolution failures match nothing
# (the ~~not_found~~ sentinel) instead of erroring; nesting is forbidden.

RSpec.describe TagQuery do
  include_context "as member"

  let!(:saved_search) { create(:saved_search, user: CurrentUser.user, name: "my_search", query: "fox cat") }

  def spliced(parsed, bucket = :must)
    parsed[:groups][bucket].first
  end

  describe "resolution" do
    it "splices the referenced query as a must group by name" do
      tq = TagQuery.new("search:my_search")
      sub = spliced(tq)
      expect(sub).to be_a(TagQuery)
      expect(sub[:tags][:must]).to match_array(%w[fox cat])
    end

    it "splices by id" do
      tq = TagQuery.new("search:#{saved_search.id}")
      expect(spliced(tq)[:tags][:must]).to match_array(%w[fox cat])
    end

    it "puts -search: groups in must_not" do
      tq = TagQuery.new("-search:my_search")
      expect(spliced(tq, :must_not)[:tags][:must]).to match_array(%w[fox cat])
    end

    it "puts ~search: groups in should" do
      tq = TagQuery.new("~search:my_search")
      expect(spliced(tq, :should)[:tags][:must]).to match_array(%w[fox cat])
    end

    it "composes with additional tags" do
      tq = TagQuery.new("search:my_search solo")
      expect(tq[:tags][:must]).to include("solo")
      expect(spliced(tq)).to be_a(TagQuery)
    end

    it "works inside a processed group" do
      # A lone unprefixed top-level group gets unwrapped by the scanner; the sibling tag keeps it a real group.
      tq = TagQuery.new("solo ( search:my_search )", process_groups: true)
      outer = tq[:groups][:must].first
      expect(outer[:groups][:must].first[:tags][:must]).to match_array(%w[fox cat])
    end
  end

  describe "resolution failure" do
    it "matches nothing for an unknown name" do
      tq = TagQuery.new("search:no_such_search")
      expect(tq[:tags][:must]).to include("~~not_found~~")
      expect(tq[:groups]).to be_blank
    end

    it "matches nothing for another user's saved search id" do
      other = create(:saved_search, query: "dog")
      tq = TagQuery.new("search:#{other.id}")
      expect(tq[:tags][:must]).to include("~~not_found~~")
    end

    it "matches nothing for anonymous users" do
      CurrentUser.user = User.anonymous
      tq = TagQuery.new("search:my_search")
      expect(tq[:tags][:must]).to include("~~not_found~~")
    end

    it "is a no-op for a negated unknown reference" do
      tq = TagQuery.new("-search:no_such_search fox")
      expect(tq[:tags][:must_not]).to include("~~not_found~~")
      expect(tq[:tags][:must]).to include("fox")
    end
  end

  describe "nesting ban" do
    it "raises when a saved search references another saved search" do
      create(:saved_search, user: CurrentUser.user, name: "inner", query: "dog")
      saved_search.update_column(:query, "search:inner")
      expect { TagQuery.new("search:my_search") }.to raise_error(TagQuery::InvalidTagError)
    end

    it "raises when parsed directly with the metatag disallowed" do
      expect { TagQuery.new("search:my_search", allow_saved_search_metatag: false) }.to raise_error(TagQuery::InvalidTagError, /saved search/)
    end
  end

  describe "restrictions inside the spliced subtree" do
    it "rejects wildcards that slipped into a stored query" do
      saved_search.update_column(:query, "fox_*")
      expect { TagQuery.new("search:my_search") }.to raise_error(TagQuery::InvalidTagError)
    end

    it "enforces the reserved-slot tag budget" do
      limit = Danbooru.config.tag_query_limit
      saved_search.update_column(:query, (1..limit).map { |n| "tag_#{n}" }.join(" "))
      expect { TagQuery.new("search:my_search") }.to raise_error(TagQuery::CountExceededError)
    end

    it "accepts a stored query at the saved-search limit" do
      limit = Danbooru.config.tag_query_limit - 1
      saved_search.update_column(:query, (1..limit).map { |n| "tag_#{n}" }.join(" "))
      expect { TagQuery.new("search:my_search") }.not_to raise_error
    end
  end

  describe "tag accounting" do
    it "costs exactly one tag" do
      tq = TagQuery.new("search:my_search")
      expect(tq.tag_count).to eq(1)
    end
  end

  describe "deleted-post filtering" do
    it "propagates show-deleted overrides from the spliced query" do
      saved_search.update_column(:query, "fox status:deleted")
      tq = TagQuery.new("search:my_search")
      expect(tq.hide_deleted_posts?(at_any_level: true)).to be(false)
    end
  end
end
