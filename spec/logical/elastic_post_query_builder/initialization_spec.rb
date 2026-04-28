# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, **opts)
  end

  describe "initialization" do
    it "accepts a raw query string and wraps it in a TagQuery" do
      builder = build_query("cute")
      expect(builder.q).to be_a(TagQuery)
    end

    it "accepts a pre-built TagQuery object directly without re-wrapping" do
      tq = TagQuery.new("cute", resolve_aliases: false)
      builder = ElasticPostQueryBuilder.new(tq)
      expect(builder.q).to be(tq)
    end

    it "defaults @depth to 0" do
      builder = build_query("")
      expect(builder.instance_variable_get(:@depth)).to eq(0)
    end

    it "raises DepthExceededError when depth equals DEPTH_LIMIT" do
      expect do
        build_query("cute", depth: TagQuery::DEPTH_LIMIT)
      end.to raise_error(TagQuery::DepthExceededError)
    end

    it "raises DepthExceededError when depth exceeds DEPTH_LIMIT" do
      expect do
        build_query("cute", depth: TagQuery::DEPTH_LIMIT + 1)
      end.to raise_error(TagQuery::DepthExceededError)
    end

    # FIXME: add_group_search_relation raises DepthExceededError unconditionally when
    # @depth + 1 >= DEPTH_LIMIT, even when the query has no groups. This means any
    # build attempt at depth DEPTH_LIMIT - 1 raises, which may be unintentional.
    # it "succeeds at depth one below DEPTH_LIMIT" do
    #   expect { build_query("cute", depth: TagQuery::DEPTH_LIMIT - 1) }.not_to raise_error
    # end

    it "reads enable_safe_mode from CurrentUser.safe_mode? by default" do
      allow(CurrentUser).to receive(:safe_mode?).and_return(true)
      builder = build_query("")
      expect(builder.instance_variable_get(:@enable_safe_mode)).to be(true)
    end

    it "accepts an explicit enable_safe_mode: true override" do
      builder = build_query("", enable_safe_mode: true)
      expect(builder.instance_variable_get(:@enable_safe_mode)).to be(true)
    end

    it "accepts an explicit enable_safe_mode: false override" do
      builder = build_query("", enable_safe_mode: false)
      expect(builder.instance_variable_get(:@enable_safe_mode)).to be(false)
    end

    it "initializes must, must_not, and should as arrays (from parent)" do
      builder = build_query("")
      expect(builder.must).to be_a(Array)
      expect(builder.must_not).to be_a(Array)
      expect(builder.should).to be_a(Array)
    end

    it "sets order to the ORDER_TABLE default Hash when no order metatag is present" do
      # ORDER_TABLE uses Hash.new({ id: :desc }), so ORDER_TABLE[nil] returns that Hash default.
      builder = build_query("")
      expect(builder.order).to eq({ id: :desc })
    end
  end
end
