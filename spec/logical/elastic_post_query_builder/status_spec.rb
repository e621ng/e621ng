# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "status metatag" do
    describe "status:pending" do
      it "adds pending:true to must" do
        expect(build_query("status:pending").must).to include({ term: { pending: true } })
      end
    end

    describe "status:flagged" do
      it "adds flagged:true to must" do
        expect(build_query("status:flagged").must).to include({ term: { flagged: true } })
      end
    end

    describe "status:modqueue" do
      it "adds a match_any(pending, flagged) clause to must" do
        clause = { bool: { minimum_should_match: 1, should: [{ term: { pending: true } }, { term: { flagged: true } }] } }
        expect(build_query("status:modqueue").must).to include(clause)
      end
    end

    describe "status:deleted" do
      it "adds deleted:true to must" do
        expect(build_query("status:deleted").must).to include({ term: { deleted: true } })
      end

      it "does not add a deleted:false filter" do
        expect(build_query("status:deleted").must).not_to include({ term: { deleted: false } })
      end
    end

    describe "status:active" do
      it "adds pending:false, deleted:false, and flagged:false to must" do
        must = build_query("status:active").must
        expect(must).to include({ term: { pending: false } })
        expect(must).to include({ term: { deleted: false } })
        expect(must).to include({ term: { flagged: false } })
      end
    end

    describe "status:all" do
      it "adds no status-specific clause to must" do
        must = build_query("status:all").must
        expect(must).not_to include({ term: { pending: true } })
        expect(must).not_to include({ term: { pending: false } })
        expect(must).not_to include({ term: { deleted: true } })
        expect(must).not_to include({ term: { deleted: false } })
      end
    end

    describe "status:any" do
      it "adds no status-specific clause to must" do
        must = build_query("status:any").must
        expect(must).not_to include({ term: { pending: true } })
        expect(must).not_to include({ term: { deleted: true } })
        expect(must).not_to include({ term: { deleted: false } })
      end
    end
  end

  describe "negated status metatag (-status:)" do
    describe "-status:pending" do
      it "adds pending:true to must_not" do
        expect(build_query("-status:pending").must_not).to include({ term: { pending: true } })
      end
    end

    describe "-status:flagged" do
      it "adds flagged:true to must_not" do
        expect(build_query("-status:flagged").must_not).to include({ term: { flagged: true } })
      end
    end

    describe "-status:modqueue" do
      it "adds a match_any(pending, flagged) clause to must_not" do
        clause = { bool: { minimum_should_match: 1, should: [{ term: { pending: true } }, { term: { flagged: true } }] } }
        expect(build_query("-status:modqueue").must_not).to include(clause)
      end
    end

    describe "-status:deleted" do
      it "adds deleted:true to must_not" do
        expect(build_query("-status:deleted").must_not).to include({ term: { deleted: true } })
      end

      it "does not add a deleted:false filter (show_deleted is set)" do
        expect(build_query("-status:deleted").must).not_to include({ term: { deleted: false } })
      end
    end

    describe "-status:active" do
      it "adds a match_any(pending, deleted, flagged) clause to must" do
        clause = {
          bool: {
            minimum_should_match: 1,
            should: [
              { term: { pending: true } },
              { term: { deleted: true } },
              { term: { flagged: true } },
            ],
          },
        }
        expect(build_query("-status:active").must).to include(clause)
      end

      it "does not add a deleted:false filter (show_deleted is set)" do
        expect(build_query("-status:active").must).not_to include({ term: { deleted: false } })
      end
    end
  end
end
