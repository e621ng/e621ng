# frozen_string_literal: true

require "rails_helper"

# Tests numeric/range metatags.
#
# All range values are stored as ParseValue arrays:
#   [:eq, n]            — exact match
#   [:gt, n]            — greater than
#   [:gte, n]           — greater than or equal
#   [:lt, n]            — less than
#   [:lte, n]           — less than or equal
#   [:between, min, max] — inclusive range
#
# The values are appended to an array via add_to_query, so e.g. q[:post_id] = [[:between, 1, 100]].
#
# Note: filesize and mpixels use range_fudged, which converts an exact value to a ±5% range.
# Date and age are tested at the structural level without pinning exact timestamps.

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  # ---------------------------------------------------------------------------
  # Shared behaviour: range operator parsing
  # ---------------------------------------------------------------------------

  shared_examples "a range metatag" do |metatag:, key:|
    it "parses an exact value as [:eq, n]" do
      tq = TagQuery.new("#{metatag}:50")
      expect(tq[key].first).to eq([:eq, 50])
    end

    it "parses a min..max range as [:between, min, max]" do
      tq = TagQuery.new("#{metatag}:10..20")
      expect(tq[key].first).to eq([:between, 10, 20])
    end

    it "parses >n as [:gt, n]" do
      tq = TagQuery.new("#{metatag}:>100")
      expect(tq[key].first).to eq([:gt, 100])
    end

    it "parses >=n as [:gte, n]" do
      tq = TagQuery.new("#{metatag}:>=100")
      expect(tq[key].first).to eq([:gte, 100])
    end

    it "parses <n as [:lt, n]" do
      tq = TagQuery.new("#{metatag}:<100")
      expect(tq[key].first).to eq([:lt, 100])
    end

    it "parses <=n as [:lte, n]" do
      tq = TagQuery.new("#{metatag}:<=100")
      expect(tq[key].first).to eq([:lte, 100])
    end

    it "parses a comma-separated list of integers as [:in, [*list]]" do
      tq = TagQuery.new("#{metatag}:1,23,456")
      expect(tq[key].first).to eq([:in, [1, 23, 456]])
    end

    it "truncates a comma-separated list of integers at #{Danbooru.config.max_per_page}" do
      limit = Danbooru.config.max_per_page
      tq = TagQuery.new("#{metatag}:#{[*(1..limit)].join(',')}")
      expect(tq[key].first).to eq([:in, [*(1..limit)]])
      tq = TagQuery.new("#{metatag}:#{[*(1..(limit + 10))].join(',')}")
      expect(tq[key].first).to eq([:in, [*(1..limit)]])
    end

    it "stores a negated range in #{key}_must_not" do
      tq = TagQuery.new("-#{metatag}:50")
      expect(tq[:"#{key}_must_not"].first).to eq([:eq, 50])
    end

    it "stores a should range in #{key}_should" do
      tq = TagQuery.new("~#{metatag}:50")
      expect(tq[:"#{key}_should"].first).to eq([:eq, 50])
    end
  end

  # ---------------------------------------------------------------------------
  # id
  # ---------------------------------------------------------------------------

  describe "id: metatag" do
    include_examples "a range metatag", metatag: "id", key: :post_id
  end

  # ---------------------------------------------------------------------------
  # Score, favcount
  # ---------------------------------------------------------------------------

  describe "score: metatag" do
    include_examples "a range metatag", metatag: "score", key: :score

    it "supports negative values in a range" do
      tq = TagQuery.new("score:-100..100")
      expect(tq[:score].first).to eq([:between, -100, 100])
    end
  end

  describe "favcount: metatag" do
    include_examples "a range metatag", metatag: "favcount", key: :fav_count
  end

  # ---------------------------------------------------------------------------
  # Dimensions
  # ---------------------------------------------------------------------------

  describe "width: metatag" do
    include_examples "a range metatag", metatag: "width", key: :width
  end

  describe "height: metatag" do
    include_examples "a range metatag", metatag: "height", key: :height
  end

  describe "mpixels: metatag" do
    it "converts an exact value to a ±5% fudged [:between, min, max] range" do
      tq = TagQuery.new("mpixels:10")
      expect(tq[:mpixels].first.first).to eq(:between)
    end

    it "passes a min..max range through as [:between, min, max]" do
      tq = TagQuery.new("mpixels:5..10")
      expect(tq[:mpixels].first.first).to eq(:between)
    end
  end

  describe "ratio: metatag" do
    it "parses a decimal ratio value" do
      tq = TagQuery.new("ratio:1.78")
      expect(tq[:ratio].first.first).to eq(:eq)
    end

    it "parses a colon-separated ratio (16:9)" do
      tq = TagQuery.new("ratio:16:9")
      # 16/9 ≈ 1.78
      value = tq[:ratio].first
      expect(value.first).to eq(:eq)
      expect(value[1]).to be_within(0.01).of(1.78)
    end
  end

  describe "duration: metatag" do
    include_examples "a range metatag", metatag: "duration", key: :duration
  end

  # ---------------------------------------------------------------------------
  # File size
  # ---------------------------------------------------------------------------

  describe "filesize: metatag" do
    it "converts an exact value to a ±5% fudged [:between, min, max] range" do
      tq = TagQuery.new("filesize:1000000")
      result = tq[:filesize].first
      expect(result.first).to eq(:between)
    end

    it "interprets an MB suffix" do
      tq_mb = TagQuery.new("filesize:1mb")
      tq_raw = TagQuery.new("filesize:1048576")
      expect(tq_mb[:filesize].first).to eq(tq_raw[:filesize].first)
    end

    it "passes a min..max range through unchanged" do
      tq = TagQuery.new("filesize:100000..200000")
      expect(tq[:filesize].first.first).to eq(:between)
    end
  end

  # ---------------------------------------------------------------------------
  # change, tagcount
  # ---------------------------------------------------------------------------

  describe "change: metatag" do
    include_examples "a range metatag", metatag: "change", key: :change_seq
  end

  describe "tagcount: metatag" do
    include_examples "a range metatag", metatag: "tagcount", key: :post_tag_count
  end

  # ---------------------------------------------------------------------------
  # Tag category counts
  # ---------------------------------------------------------------------------

  describe "category count metatags" do
    it "dirtags: stores a range under :director_tag_count" do
      tq = TagQuery.new("dirtags:1..5")
      expect(tq[:director_tag_count].first).to eq([:between, 1, 5])
    end

    it "franctags: stores a range under :franchise_tag_count" do
      tq = TagQuery.new("franctags:3")
      expect(tq[:franchise_tag_count].first).to eq([:eq, 3])
    end

    it "chartags: stores a range under :character_tag_count" do
      tq = TagQuery.new("chartags:>0")
      expect(tq[:character_tag_count].first).to eq([:gt, 0])
    end

    it "gentags: stores a range under :general_tag_count" do
      tq = TagQuery.new("gentags:10..50")
      expect(tq[:general_tag_count].first).to eq([:between, 10, 50])
    end
  end

  # ---------------------------------------------------------------------------
  # comment_count (COUNT_METATAG – stored directly, not via add_to_query)
  # ---------------------------------------------------------------------------

  describe "comment_count: metatag" do
    it "stores a ParseValue range directly in q[:comment_count]" do
      tq = TagQuery.new("comment_count:5")
      expect(tq[:comment_count]).to eq([:eq, 5])
    end

    it "parses a range for comment_count" do
      tq = TagQuery.new("comment_count:1..10")
      expect(tq[:comment_count]).to eq([:between, 1, 10])
    end
  end

  # ---------------------------------------------------------------------------
  # Date and age
  # ---------------------------------------------------------------------------

  describe "date: metatag" do
    it "parses a date range and stores a :between tuple in q[:date]" do
      tq = TagQuery.new("date:2023-01-01..2023-12-31")
      result = tq[:date].first
      expect(result.first).to eq(:between)
      expect(result[1]).to be_present
      expect(result[2]).to be_present
    end

    it "parses a single date as an :eq tuple" do
      tq = TagQuery.new("date:2023-06-15")
      result = tq[:date].first
      expect(result.first).to eq(:eq)
    end
  end

  describe "age: metatag" do
    it "parses an age string and stores a result in q[:age]" do
      tq = TagQuery.new("age:7d")
      expect(tq[:age]).to be_present
    end

    it "inverts the range operator for age" do
      # age:>7d means "older than 7 days" => the stored range is :lt (created before)
      tq = TagQuery.new("age:>7d")
      result = tq[:age].first
      expect(result.first).to eq(:lt)
    end
  end
end
