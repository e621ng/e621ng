# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "group search" do
    # Group syntax: spaces required inside parens. A standalone group like ( cute ) is
    # automatically "unwrapped" by TagQuery when it comprises the entire query. At least
    # one outer tag or a polarity prefix (-/~) is needed to keep the group intact.
    describe "must groups" do
      it "adds a nested bool clause to must when a group accompanies an outer tag" do
        # "score:>0 ( cute )" — outer metatag keeps the group from being unwrapped
        must = build_query("score:>0 ( cute )").must
        nested = must.find { |c| c.dig(:bool, :must) }
        expect(nested).to be_present
        expect(nested.dig(:bool, :must)).to include({ term: { tags: "cute" } })
      end
    end

    describe "must_not groups" do
      it "adds a nested bool clause to must_not for -( group )" do
        must_not = build_query("-( cute )").must_not
        nested = must_not.find { |c| c.dig(:bool, :must) }
        expect(nested).to be_present
      end
    end

    describe "should groups" do
      it "adds a nested bool clause to should for ~( group )" do
        should_clauses = build_query("~( cute )").should
        nested = should_clauses.find { |c| c.dig(:bool, :must) }
        expect(nested).to be_present
      end
    end

    describe "depth limit" do
      it "raises DepthExceededError when adding a group would exceed DEPTH_LIMIT" do
        builder = build_query("cute")
        builder.instance_variable_set(:@depth, TagQuery::DEPTH_LIMIT - 1)
        expect do
          builder.add_group_search_relation({ must: ["fluffy"], must_not: [], should: [] })
        end.to raise_error(TagQuery::DepthExceededError)
      end

      it "silently returns without adding anything when error_on_depth_exceeded is false and depth would exceed limit" do
        builder = build_query("cute", error_on_depth_exceeded: false)
        builder.instance_variable_set(:@depth, TagQuery::DEPTH_LIMIT - 1)
        builder.must.clear
        builder.add_group_search_relation({ must: ["fluffy"], must_not: [], should: [] })
        expect(builder.must).to be_empty
      end
    end

    describe "empty groups" do
      it "does not modify must when all group arrays are empty" do
        builder = build_query("cute")
        before_must = builder.must.dup
        builder.add_group_search_relation({ must: [], must_not: [], should: [] })
        # Only the existing clauses from build remain
        expect(builder.must).to eq(before_must)
      end

      it "does not raise when groups is blank" do
        builder = build_query("cute")
        expect { builder.add_group_search_relation(nil) }.not_to raise_error
      end
    end

    describe "order inside groups" do
      it "does not include an order clause in the nested sub-query" do
        # Sub-queries at depth > 0 skip the order case statement.
        # Use an outer tag so the group isn't unwrapped by TagQuery.
        must = build_query("cute ( order:score fluffy )").must
        nested = must.find { |c| c.dig(:bool, :must) }
        expect(nested).to be_present
        # The nested bool query should not have a sort/order key
        expect(nested).not_to have_key(:sort)
      end
    end
  end
end
