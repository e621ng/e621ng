# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  # For non-moderator members, privileged_user_id_or_invalid always returns
  # CurrentUser.id regardless of the supplied username.
  describe "voted metatag" do
    it "adds a match_any(upvotes, downvotes) to must for voted:somebody" do
      voter_id = CurrentUser.id
      clause = {
        bool: {
          minimum_should_match: 1,
          should: [{ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } }],
        },
      }
      expect(build_query("voted:somebody").must).to include(clause)
    end

    it "adds both upvotes and downvotes term clauses to must_not for -voted:somebody" do
      voter_id = CurrentUser.id
      must_not = build_query("-voted:somebody").must_not
      expect(must_not).to include({ term: { upvotes: voter_id } })
      expect(must_not).to include({ term: { downvotes: voter_id } })
    end

    it "adds both upvotes and downvotes term clauses to should for ~voted:somebody" do
      voter_id = CurrentUser.id
      should_clauses = build_query("~voted:somebody").should
      expect(should_clauses).to include({ term: { upvotes: voter_id } })
      expect(should_clauses).to include({ term: { downvotes: voter_id } })
    end
  end

  describe "upvote metatag" do
    it "adds an upvotes term clause to must for upvote:somebody" do
      voter_id = CurrentUser.id
      expect(build_query("upvote:somebody").must).to include({ term: { upvotes: voter_id } })
    end

    it "adds an upvotes term clause to must_not for -upvote:somebody" do
      voter_id = CurrentUser.id
      expect(build_query("-upvote:somebody").must_not).to include({ term: { upvotes: voter_id } })
    end
  end

  describe "downvote metatag" do
    it "adds a downvotes term clause to must for downvote:somebody" do
      voter_id = CurrentUser.id
      expect(build_query("downvote:somebody").must).to include({ term: { downvotes: voter_id } })
    end
  end
end
