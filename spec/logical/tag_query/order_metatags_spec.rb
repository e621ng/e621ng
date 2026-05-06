# frozen_string_literal: true

require "rails_helper"

# Tests the order: and -order: metatags, including alias normalisation, inversion,
# non-suffixed aliases, and randseed:.
#
# Key constants:
#   TagQuery::ORDER_INVERTIBLE_ALIASES  — aliases that normalise to an ORDER_INVERTIBLE_ROOT
#   TagQuery::ORDER_NON_SUFFIXED_ALIASES — aliases that resolve to a specific non-root form
#   TagQuery::ORDER_VALUE_INVERSIONS     — maps a value to its inverted counterpart

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe "order: metatag" do
    it "stores the value directly in q[:order]" do
      expect(TagQuery.new("order:score")[:order]).to eq("score")
    end

    it "normalises the value to lowercase" do
      expect(TagQuery.new("order:Score")[:order]).to eq("score")
    end

    it "passes through an already-valid _asc-suffixed value" do
      expect(TagQuery.new("order:score_asc")[:order]).to eq("score_asc")
    end

    it "strips a superfluous _desc suffix for most invertible roots" do
      # score_desc is equivalent to score; normalise_order_value strips it
      expect(TagQuery.new("order:score_desc")[:order]).to eq("score")
    end

    describe "ORDER_INVERTIBLE_ALIASES" do
      it "comm: normalises to 'comment'" do
        expect(TagQuery.new("order:comm")[:order]).to eq("comment")
      end

      it "comm_bumped: normalises to 'comment_bumped'" do
        expect(TagQuery.new("order:comm_bumped")[:order]).to eq("comment_bumped")
      end

      it "size: normalises to 'filesize'" do
        expect(TagQuery.new("order:size")[:order]).to eq("filesize")
      end

      it "ratio: normalises to 'aspect_ratio'" do
        expect(TagQuery.new("order:ratio")[:order]).to eq("aspect_ratio")
      end

      it "comm_asc: normalises to 'comment_asc'" do
        expect(TagQuery.new("order:comm_asc")[:order]).to eq("comment_asc")
      end
    end

    describe "ORDER_NON_SUFFIXED_ALIASES" do
      it "portrait: normalises to 'aspect_ratio_asc'" do
        expect(TagQuery.new("order:portrait")[:order]).to eq("aspect_ratio_asc")
      end

      it "landscape: normalises to 'aspect_ratio'" do
        expect(TagQuery.new("order:landscape")[:order]).to eq("aspect_ratio")
      end

      it "rank: normalises to 'hot'" do
        expect(TagQuery.new("order:rank")[:order]).to eq("hot")
      end
    end
  end

  describe "-order: (negated / inverted order)" do
    it "-order:score inverts to score_asc" do
      expect(TagQuery.new("-order:score")[:order]).to eq("score_asc")
    end

    it "-order:score_asc inverts back to score" do
      expect(TagQuery.new("-order:score_asc")[:order]).to eq("score")
    end

    it "-order:id inverts to id_desc (id is a special case)" do
      expect(TagQuery.new("-order:id")[:order]).to eq("id_desc")
    end

    it "-order:id_desc inverts to id" do
      expect(TagQuery.new("-order:id_desc")[:order]).to eq("id")
    end

    it "-order:comm inverts the resolved alias (comment → comment_asc)" do
      expect(TagQuery.new("-order:comm")[:order]).to eq("comment_asc")
    end

    it "-order:portrait inverts to landscape's resolved form" do
      # portrait → aspect_ratio_asc; inversion of aspect_ratio_asc is aspect_ratio
      expect(TagQuery.new("-order:portrait")[:order]).to eq("aspect_ratio")
    end

    it "-order:landscape inverts to portrait's resolved form" do
      # landscape → aspect_ratio; inversion is aspect_ratio_asc
      expect(TagQuery.new("-order:landscape")[:order]).to eq("aspect_ratio_asc")
    end
  end

  describe "randseed: metatag" do
    it "stores the seed value in q[:random_seed]" do
      tq = TagQuery.new("randseed:42")
      expect(tq[:random_seed]).to eq(42)
    end

    it "auto-sets order to 'random' when no explicit order is given" do
      tq = TagQuery.new("randseed:99")
      expect(tq[:order]).to eq("random")
    end

    it "does not override an explicit order metatag" do
      tq = TagQuery.new("order:score randseed:7")
      expect(tq[:order]).to eq("score")
      expect(tq[:random_seed]).to eq(7)
    end
  end

  describe "hot_from: metatag" do
    it "stores a parsed date in q[:hot_from]" do
      tq = TagQuery.new("hot_from:2023-01-01")
      expect(tq[:hot_from]).to be_present
    end
  end

  describe "limit: metatag" do
    it "is consumed by the controller and leaves no trace in q" do
      tq = TagQuery.new("limit:20 tag_a", resolve_aliases: false)
      expect(tq.include?(:limit)).to be(false)
      expect(tq[:tags][:must]).to include("tag_a")
    end
  end
end
