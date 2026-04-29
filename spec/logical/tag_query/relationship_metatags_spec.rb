# frozen_string_literal: true

require "rails_helper"

# Tests relationship metatags: pool:, set:, parent:, and child:.
#
# Pool and set name resolution (non-numeric) is stubbed because no factory exists
# for those models. Numeric IDs are used for most cases to exercise the parsing path
# without side-effects.

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe "pool: metatag" do
    it "stores a numeric pool ID in pool_ids" do
      tq = TagQuery.new("pool:42")
      expect(tq[:pool_ids]).to include(42)
    end

    it "stores multiple pool IDs across successive metatags" do
      tq = TagQuery.new("pool:1 pool:2")
      expect(tq[:pool_ids]).to include(1, 2)
    end

    it "pool:any sets q[:pool] to 'any'" do
      tq = TagQuery.new("pool:any")
      expect(tq[:pool]).to eq("any")
      expect(tq[:pool_ids]).to be_nil
    end

    it "pool:none sets q[:pool] to 'none'" do
      tq = TagQuery.new("pool:none")
      expect(tq[:pool]).to eq("none")
    end

    it "-pool:any inverts to 'none'" do
      tq = TagQuery.new("-pool:any")
      expect(tq[:pool]).to eq("none")
    end

    it "-pool:none inverts to 'any'" do
      tq = TagQuery.new("-pool:none")
      expect(tq[:pool]).to eq("any")
    end

    it "~pool:any stores 'any' in pool_should" do
      tq = TagQuery.new("~pool:any")
      expect(tq[:pool_should]).to eq("any")
    end

    it "-pool:ID stores ID in pool_ids_must_not" do
      tq = TagQuery.new("-pool:7")
      expect(tq[:pool_ids_must_not]).to include(7)
    end

    it "~pool:ID stores ID in pool_ids_should" do
      tq = TagQuery.new("~pool:7")
      expect(tq[:pool_ids_should]).to include(7)
    end

    context "with a named pool" do
      before do
        allow(Pool).to receive(:name_to_id).with("my_pool").and_return(99)
      end

      it "resolves a pool name to its ID" do
        tq = TagQuery.new("pool:my_pool")
        expect(tq[:pool_ids]).to include(99)
      end
    end
  end

  describe "set: metatag" do
    before do
      allow(PostSet).to receive_messages(
        name_to_id: nil,
        find_by: nil,
      )
    end

    it "stores -1 when the set cannot be found" do
      tq = TagQuery.new("set:unknown_set")
      expect(tq[:set_ids]).to include(-1)
    end

    context "with a discoverable set" do
      let(:mock_set) { instance_double(PostSet, id: 55, can_view?: true) }

      before do
        allow(PostSet).to receive(:name_to_id).with("visible_set").and_return(55)
        allow(PostSet).to receive(:find_by).with(id: 55).and_return(mock_set)
      end

      it "stores the set ID in set_ids" do
        tq = TagQuery.new("set:visible_set")
        expect(tq[:set_ids]).to include(55)
      end
    end
  end

  describe "parent: metatag" do
    it "stores a numeric parent ID in parent_ids" do
      tq = TagQuery.new("parent:123")
      expect(tq[:parent_ids]).to include(123)
    end

    it "parent:any sets q[:parent] to 'any'" do
      tq = TagQuery.new("parent:any")
      expect(tq[:parent]).to eq("any")
      expect(tq[:parent_ids]).to be_nil
    end

    it "parent:none sets q[:parent] to 'none'" do
      tq = TagQuery.new("parent:none")
      expect(tq[:parent]).to eq("none")
    end

    it "-parent:any inverts to 'none'" do
      tq = TagQuery.new("-parent:any")
      expect(tq[:parent]).to eq("none")
    end

    it "-parent:ID stores ID in parent_ids_must_not" do
      tq = TagQuery.new("-parent:123")
      expect(tq[:parent_ids_must_not]).to include(123)
    end

    it "~parent:ID stores ID in parent_ids_should" do
      tq = TagQuery.new("~parent:123")
      expect(tq[:parent_ids_should]).to include(123)
    end
  end

  describe "child: metatag" do
    it "child:any sets q[:child] to 'any'" do
      tq = TagQuery.new("child:any")
      expect(tq[:child]).to eq("any")
    end

    it "child:none sets q[:child] to 'none'" do
      tq = TagQuery.new("child:none")
      expect(tq[:child]).to eq("none")
    end
  end
end
