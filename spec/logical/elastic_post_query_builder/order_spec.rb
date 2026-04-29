# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "ORDER_TABLE lookups (depth 0)" do
    it "sets order to id asc for order:id" do
      expect(build_query("order:id").order).to eq([{ id: :asc }])
    end

    it "sets order to id desc for order:id_desc" do
      expect(build_query("order:id_desc").order).to eq([{ id: :desc }])
    end

    it "sets order to score desc then id desc for order:score" do
      expect(build_query("order:score").order).to eq([{ score: :desc }, { id: :desc }])
    end

    it "sets order to score asc then id asc for order:score_asc" do
      expect(build_query("order:score_asc").order).to eq([{ score: :asc }, { id: :asc }])
    end

    it "sets order to fav_count desc then id desc for order:favcount" do
      expect(build_query("order:favcount").order).to eq([{ fav_count: :desc }, { id: :desc }])
    end

    it "sets order to created_at desc for order:created" do
      expect(build_query("order:created").order).to eq([{ created_at: :desc }])
    end

    it "sets order to created_at asc for order:created_asc" do
      expect(build_query("order:created_asc").order).to eq([{ created_at: :asc }])
    end

    it "sets order to md5 desc for order:md5" do
      expect(build_query("order:md5").order).to eq([{ md5: :desc }])
    end

    it "uses the Hash.new default { id: :desc } for an unrecognized order value" do
      expect(build_query("order:nosuchorder").order).to eq({ id: :desc })
    end

    it "uses the Hash.new default when no order metatag is present" do
      expect(build_query("cute").order).to eq({ id: :desc })
    end
  end

  describe "comment_bumped order" do
    it "sets order from ORDER_TABLE for order:comment_bumped" do
      builder = build_query("order:comment_bumped")
      expect(builder.order).to eq([{ comment_bumped_at: { order: :desc, missing: :_last } }, { id: :desc }])
    end

    it "adds an exists clause on comment_bumped_at to must for order:comment_bumped" do
      expect(build_query("order:comment_bumped").must).to include({ exists: { field: "comment_bumped_at" } })
    end

    it "sets order from ORDER_TABLE for order:comment_bumped_asc" do
      builder = build_query("order:comment_bumped_asc")
      expect(builder.order).to eq([{ comment_bumped_at: { order: :asc, missing: :_last } }, { id: :desc }])
    end

    it "adds an exists clause on comment_bumped_at to must for order:comment_bumped_asc" do
      expect(build_query("order:comment_bumped_asc").must).to include({ exists: { field: "comment_bumped_at" } })
    end
  end

  describe "COUNT_METATAG order pattern" do
    it "orders by comment_count desc for order:comment_count" do
      builder = build_query("order:comment_count")
      expect(builder.order).to include({ "comment_count" => "desc" })
      expect(builder.order).to include({ id: "desc" })
    end

    it "orders by comment_count asc for order:comment_count_asc" do
      builder = build_query("order:comment_count_asc")
      expect(builder.order).to include({ "comment_count" => "asc" })
      expect(builder.order).to include({ id: "asc" })
    end
  end

  describe "category tag count order pattern" do
    TagCategory::SHORT_NAME_MAPPING.each do |short_name, full_name|
      it "orders by tag_count_#{full_name} desc for order:#{short_name}tags" do
        expect(build_query("order:#{short_name}tags").order).to include({ "tag_count_#{full_name}" => :desc })
      end

      it "orders by tag_count_#{full_name} asc for order:#{short_name}tags_asc" do
        expect(build_query("order:#{short_name}tags_asc").order).to include({ "tag_count_#{full_name}" => :asc })
      end
    end
  end

  describe "order:random" do
    it "sets @function_score with a random_score component" do
      builder = build_query("order:random")
      fs = builder.instance_variable_get(:@function_score)
      expect(fs).to be_present
      expect(fs).to have_key(:random_score)
    end

    it "sets boost_mode to :replace for order:random" do
      builder = build_query("order:random")
      fs = builder.instance_variable_get(:@function_score)
      expect(fs[:boost_mode]).to eq(:replace)
    end

    it "pushes _score:desc onto order for order:random" do
      expect(build_query("order:random").order).to include({ _score: :desc })
    end

    it "includes the seed in the random_score for randseed:42" do
      builder = build_query("order:random randseed:42")
      fs = builder.instance_variable_get(:@function_score)
      expect(fs[:random_score]).to include(seed: 42)
    end

    it "uses an empty hash for random_score when no randseed is given" do
      builder = build_query("order:random")
      fs = builder.instance_variable_get(:@function_score)
      expect(fs[:random_score]).to eq({})
    end

    it "automatically sets order to random when only randseed is given (no explicit order)" do
      builder = build_query("randseed:99")
      fs = builder.instance_variable_get(:@function_score)
      expect(fs).to be_present
      expect(fs).to have_key(:random_score)
    end
  end

  describe "order:hot" do
    it "sets @function_score with a script_score component" do
      builder = build_query("order:hot")
      fs = builder.instance_variable_get(:@function_score)
      expect(fs).to be_present
      expect(fs).to have_key(:script_score)
    end

    it "pushes a score > 0 range clause to must" do
      expect(build_query("order:hot").must).to include({ range: { score: { gt: 0 } } })
    end

    it "pushes a created_at range clause to must" do
      must = build_query("order:hot").must
      range_clause = must.find { |c| c.dig(:range, :created_at) }
      expect(range_clause).to be_present
    end

    it "pushes _score:desc onto order" do
      expect(build_query("order:hot").order).to include({ _score: :desc })
    end

    it "includes gte and no lte when no hot_from is given" do
      must = build_query("order:hot").must
      range_clause = must.find { |c| c.dig(:range, :created_at) }
      expect(range_clause.dig(:range, :created_at)).to have_key(:gte)
      expect(range_clause.dig(:range, :created_at)).not_to have_key(:lte)
    end
  end

  describe "order at depth > 0" do
    it "does not modify the order array when depth is 1" do
      builder = build_query("order:score", depth: 1)
      expect(builder.order).to be_empty
    end
  end
end
