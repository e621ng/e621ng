# frozen_string_literal: true

require "rails_helper"

# Tests TagQuery initialization: default @q structure, options, and delegate methods.

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe "initialization" do
    describe "default @q structure" do
      subject(:tq) { TagQuery.new("") }

      it "initializes tags with empty must, must_not, and should arrays" do
        expect(tq[:tags]).to eq({ must: [], must_not: [], should: [] })
      end

      it "sets show_deleted to false" do
        expect(tq[:show_deleted]).to be(false)
      end

      it "exposes @q via the #q reader" do
        expect(tq.q).to be_a(Hash)
        expect(tq.q[:tags]).to eq({ must: [], must_not: [], should: [] })
      end
    end

    describe "#tag_count" do
      it "is 0 for a blank query" do
        expect(TagQuery.new("").tag_count).to eq(0)
      end

      it "increments for each plain tag parsed" do
        tq = TagQuery.new("tag_a tag_b tag_c", resolve_aliases: false)
        expect(tq.tag_count).to eq(3)
      end
    end

    describe "resolve_aliases option" do
      it "defaults to true" do
        expect(TagQuery.new("").resolve_aliases).to be(true)
      end

      it "stores false when explicitly passed" do
        expect(TagQuery.new("", resolve_aliases: false).resolve_aliases).to be(false)
      end
    end

    describe "free_tags_count option" do
      it "reduces the effective tag_query_limit" do
        baseline = TagQuery.new("").tag_query_limit
        tq = TagQuery.new("", free_tags_count: 3)
        expect(tq.tag_query_limit).to eq(baseline - 3)
      end

      it "is reflected in tag_surplus" do
        tq = TagQuery.new("tag_a", free_tags_count: 2)
        expect(tq.tag_surplus).to eq(tq.tag_query_limit - 1)
      end
    end

    describe "[] delegation" do
      it "delegates [] to @q" do
        tq = TagQuery.new("status:pending")
        expect(tq[:status]).to eq("pending")
      end
    end

    describe "include? delegation" do
      it "returns true for keys that were set" do
        tq = TagQuery.new("order:score")
        expect(tq.include?(:order)).to be(true)
      end

      it "returns false for keys that were never set" do
        tq = TagQuery.new("")
        expect(tq.include?(:order)).to be(false)
      end
    end

    describe "blank / whitespace-only query" do
      it "produces empty tag arrays and no metatags" do
        tq = TagQuery.new("   ")
        expect(tq[:tags]).to eq({ must: [], must_not: [], should: [] })
        expect(tq[:order]).to be_nil
        expect(tq[:status]).to be_nil
      end
    end

    describe "randseed auto-sets order to random" do
      it "sets order to 'random' when only randseed is present" do
        tq = TagQuery.new("randseed:42")
        expect(tq[:order]).to eq("random")
        expect(tq[:random_seed]).to eq(42)
      end

      it "preserves an explicit order when randseed is also present" do
        tq = TagQuery.new("order:score randseed:42")
        expect(tq[:order]).to eq("score")
        expect(tq[:random_seed]).to eq(42)
      end
    end
  end
end
