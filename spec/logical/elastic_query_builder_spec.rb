# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticQueryBuilder do
  include_context "as member"

  let(:builder_class) do
    Class.new(ElasticQueryBuilder) do
      def build
      end
    end
  end

  def make_builder(query = {})
    builder_class.new(query)
  end

  # ---------------------------------------------------------------------------
  # #create_query_obj
  # ---------------------------------------------------------------------------

  describe "#create_query_obj" do
    subject(:builder) { make_builder }

    it "returns nil when all arrays are empty and return_nil_if_empty is true (default)" do
      expect(builder.create_query_obj).to be_nil
    end

    it "returns a query hash when return_nil_if_empty is false and all arrays are empty" do
      result = builder.create_query_obj(return_nil_if_empty: false)
      expect(result).to be_a(Hash)
      expect(result.dig(:bool, :must)).to include({ match_all: {} })
    end

    it "pushes match_all into must when must is empty but must_not is not" do
      builder.must_not.push({ term: { status: "deleted" } })
      result = builder.create_query_obj
      expect(result.dig(:bool, :must)).to include({ match_all: {} })
      expect(result.dig(:bool, :must_not)).to include({ term: { status: "deleted" } })
    end

    it "includes minimum_should_match: 1 when should is non-empty" do
      builder.should.push({ term: { rating: "s" } })
      result = builder.create_query_obj
      expect(result.dig(:bool, :minimum_should_match)).to eq(1)
    end

    it "does not include minimum_should_match when should is empty" do
      builder.must.push({ term: { rating: "s" } })
      result = builder.create_query_obj
      expect(result[:bool]).not_to have_key(:minimum_should_match)
    end

    it "wraps query in function_score when @function_score is set" do
      fs = { functions: [], score_mode: "sum" }
      builder.instance_variable_set(:@function_score, fs)
      builder.must.push({ term: { rating: "s" } })
      result = builder.create_query_obj
      expect(result).to have_key(:function_score)
      expect(result[:function_score]).to include(:query, :functions)
    end
  end

  # ---------------------------------------------------------------------------
  # #range_relation
  # ---------------------------------------------------------------------------

  describe "#range_relation" do
    subject(:builder) { make_builder }

    it "returns nil for nil input" do
      expect(builder.range_relation(nil, :score)).to be_nil
    end

    it "returns nil for an array shorter than 2 elements" do
      expect(builder.range_relation([:eq], :score)).to be_nil
    end

    it "returns nil when arr[1] is nil" do
      expect(builder.range_relation([:eq, nil], :score)).to be_nil
    end

    it "returns a term clause for :eq with a plain integer" do
      expect(builder.range_relation([:eq, 5], :score)).to eq({ term: { score: 5 } })
    end

    it "returns a day-range clause for :eq with a Time object" do
      t = Time.zone.parse("2024-06-15 12:00:00")
      result = builder.range_relation([:eq, t], :created_at)
      expect(result).to eq({ range: { created_at: { gte: t.beginning_of_day, lte: t.end_of_day } } })
    end

    it "returns a range gt clause for :gt" do
      expect(builder.range_relation([:gt, 5], :score)).to eq({ range: { score: { gt: 5 } } })
    end

    it "returns a range gte clause for :gte" do
      expect(builder.range_relation([:gte, 5], :score)).to eq({ range: { score: { gte: 5 } } })
    end

    it "returns a range lt clause for :lt" do
      expect(builder.range_relation([:lt, 5], :score)).to eq({ range: { score: { lt: 5 } } })
    end

    it "returns a range lte clause for :lte" do
      expect(builder.range_relation([:lte, 5], :score)).to eq({ range: { score: { lte: 5 } } })
    end

    it "returns a terms clause for :in with a normal array" do
      expect(builder.range_relation([:in, [1, 2, 3]], :score)).to eq({ terms: { score: [1, 2, 3] } })
    end

    it "returns nil for :in when the array contains nil (malformed)" do
      expect(builder.range_relation([:in, [1, nil, 3]], :score)).to be_nil
    end

    it "returns a between range clause for :between with both values present" do
      expect(builder.range_relation([:between, 1, 10], :score)).to eq({ range: { score: { gte: 1, lte: 10 } } })
    end

    it "returns nil for :between when arr[1] is nil" do
      expect(builder.range_relation([:between, nil, 10], :score)).to be_nil
    end

    it "returns nil for :between when arr[2] is nil" do
      expect(builder.range_relation([:between, 1, nil], :score)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # #add_array_range_relation
  # ---------------------------------------------------------------------------

  describe "#add_array_range_relation" do
    it "populates must for the base key" do
      builder = make_builder(score: [[:eq, 5]])
      builder.add_array_range_relation(:score, :score)
      expect(builder.must).to include({ term: { score: 5 } })
    end

    it "populates must_not for the _must_not-suffixed key" do
      builder = make_builder(score_must_not: [[:gt, 10]])
      builder.add_array_range_relation(:score, :score)
      expect(builder.must_not).to include({ range: { score: { gt: 10 } } })
    end

    it "populates should for the _should-suffixed key" do
      builder = make_builder(score_should: [[:lte, 3]])
      builder.add_array_range_relation(:score, :score)
      expect(builder.should).to include({ range: { score: { lte: 3 } } })
    end

    it "sets has_invalid_input to true when a must relation is malformed" do
      builder = make_builder(score: [[:in, [1, nil]]])
      builder.add_array_range_relation(:score, :score)
      expect(builder.has_invalid_input).to be(true)
    end

    it "sets has_invalid_input to true when a must_not relation is malformed" do
      builder = make_builder(score_must_not: [[:between, nil, 10]])
      builder.add_array_range_relation(:score, :score)
      expect(builder.has_invalid_input).to be(true)
    end

    it "sets has_invalid_input to true when a should relation is malformed" do
      builder = make_builder(score_should: [[:in, [nil]]])
      builder.add_array_range_relation(:score, :score)
      expect(builder.has_invalid_input).to be(true)
    end

    it "does not set has_invalid_input when all relations are valid" do
      builder = make_builder(score: [[:eq, 5]])
      builder.add_array_range_relation(:score, :score)
      expect(builder.has_invalid_input).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # #add_array_relation
  # ---------------------------------------------------------------------------

  describe "#add_array_relation" do
    it "populates must for the base key" do
      builder = make_builder(tag: ["cute"])
      builder.add_array_relation(:tag, :tags)
      expect(builder.must).to include({ term: { tags: "cute" } })
    end

    it "populates must_not for the _must_not-suffixed key" do
      builder = make_builder(tag_must_not: ["gross"])
      builder.add_array_relation(:tag, :tags)
      expect(builder.must_not).to include({ term: { tags: "gross" } })
    end

    it "populates should for the _should-suffixed key" do
      builder = make_builder(tag_should: ["fluffy"])
      builder.add_array_relation(:tag, :tags)
      expect(builder.should).to include({ term: { tags: "fluffy" } })
    end

    it "pushes an exists clause to must when any_none_key equals 'any'" do
      builder = make_builder(source: "any")
      builder.add_array_relation(:tag, :tags, any_none_key: :source)
      expect(builder.must).to include({ exists: { field: :tags } })
    end

    it "pushes an exists clause to must_not when any_none_key equals 'none'" do
      builder = make_builder(source: "none")
      builder.add_array_relation(:tag, :tags, any_none_key: :source)
      expect(builder.must_not).to include({ exists: { field: :tags } })
    end

    it "pushes an exists clause to should when any_none_key_should equals 'any'" do
      builder = make_builder(source_should: "any")
      builder.add_array_relation(:tag, :tags, any_none_key: :source)
      expect(builder.should).to include({ exists: { field: :tags } })
    end

    it "pushes a match_none wrapper to should when any_none_key_should equals 'none'" do
      builder = make_builder(source_should: "none")
      builder.add_array_relation(:tag, :tags, any_none_key: :source)
      expect(builder.should).to include({ bool: { must_not: [{ exists: { field: :tags } }] } })
    end

    it "does not push exists clauses when any_none_key is nil" do
      builder = make_builder({})
      builder.add_array_relation(:tag, :tags)
      expect(builder.must).to be_empty
      expect(builder.must_not).to be_empty
      expect(builder.should).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # #add_boolean_match
  # ---------------------------------------------------------------------------

  describe "#add_boolean_match" do
    it "does nothing when the key value is blank" do
      builder = make_builder(flag: nil)
      builder.add_boolean_match(:flag, :is_flagged)
      expect(builder.must).to be_empty
    end

    it "pushes term true for a truthy string" do
      %w[true t yes y on 1].each do |val|
        b = make_builder(flag: val)
        b.add_boolean_match(:flag, :is_flagged)
        expect(b.must).to include({ term: { is_flagged: true } }), "expected '#{val}' to be truthy"
      end
    end

    it "pushes term false for a falsy string" do
      %w[false f no n off 0].each do |val|
        b = make_builder(flag: val)
        b.add_boolean_match(:flag, :is_flagged)
        expect(b.must).to include({ term: { is_flagged: false } }), "expected '#{val}' to be falsy"
      end
    end

    it "sets has_invalid_input to true for an unrecognized value" do
      builder = make_builder(flag: "banana")
      builder.add_boolean_match(:flag, :is_flagged)
      expect(builder.has_invalid_input).to be(true)
      expect(builder.must).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # #add_range_relation
  # ---------------------------------------------------------------------------

  describe "#add_range_relation" do
    it "does nothing when the key value is blank" do
      builder = make_builder(score: nil)
      builder.add_range_relation(:score, :score)
      expect(builder.must).to be_empty
    end

    it "pushes a term clause for an exact integer string" do
      builder = make_builder(score: "5")
      builder.add_range_relation(:score, :score)
      expect(builder.must).to include({ term: { score: 5 } })
    end

    it "pushes a range gt clause for a >N string" do
      builder = make_builder(score: ">5")
      builder.add_range_relation(:score, :score)
      expect(builder.must).to include({ range: { score: { gt: 5 } } })
    end
  end

  # ---------------------------------------------------------------------------
  # #add_text_match
  # ---------------------------------------------------------------------------

  describe "#add_text_match" do
    it "does nothing when the key value is blank" do
      builder = make_builder(description: nil)
      builder.add_text_match(:description, :description)
      expect(builder.must).to be_empty
    end

    it "pushes a match clause for a non-blank string" do
      builder = make_builder(description: "hello world")
      builder.add_text_match(:description, :description)
      expect(builder.must).to include({ match: { description: "hello world" } })
    end
  end

  # ---------------------------------------------------------------------------
  # #match_any / #match_none
  # ---------------------------------------------------------------------------

  describe "#match_any" do
    it "returns a bool/should clause with minimum_should_match: 1" do
      builder = make_builder
      result = builder.match_any({ term: { a: 1 } }, { term: { b: 2 } })
      expect(result).to eq({
        bool: {
          minimum_should_match: 1,
          should: [{ term: { a: 1 } }, { term: { b: 2 } }],
        },
      })
    end
  end

  describe "#match_none" do
    it "returns a bool/must_not clause" do
      builder = make_builder
      result = builder.match_none({ term: { a: 1 } })
      expect(result).to eq({ bool: { must_not: [{ term: { a: 1 } }] } })
    end
  end

  # ---------------------------------------------------------------------------
  # #apply_basic_order / #apply_default_order
  # ---------------------------------------------------------------------------

  describe "#apply_basic_order and #apply_default_order" do
    it "appends id asc when order is 'id_asc'" do
      builder = make_builder(order: "id_asc")
      builder.apply_basic_order
      expect(builder.order).to include({ id: { order: "asc" } })
    end

    it "appends id desc when order is 'id_desc'" do
      builder = make_builder(order: "id_desc")
      builder.apply_basic_order
      expect(builder.order).to include({ id: { order: "desc" } })
    end

    it "delegates to apply_default_order for an unknown order value" do
      builder = make_builder(order: "unknown_value")
      builder.apply_basic_order
      expect(builder.order).to include({ id: { order: "desc" } })
    end

    it "appends id desc directly when apply_default_order is called" do
      builder = make_builder
      builder.apply_default_order
      expect(builder.order).to include({ id: { order: "desc" } })
    end
  end

  # ---------------------------------------------------------------------------
  # #search
  # ---------------------------------------------------------------------------

  describe "#search" do
    let(:document_store) { instance_spy(DocumentStore::ClassMethodProxy) }
    let(:model_klass) { double("model_class", document_store: document_store) } # rubocop:disable RSpec/VerifiedDoubles
    let(:search_builder_class) do
      mk = model_klass
      Class.new(ElasticQueryBuilder) do
        define_method(:model_class) { mk }
        def build
        end
      end
    end

    def make_search_builder(query = {})
      search_builder_class.new(query)
    end

    it "passes _source: false in the search body" do
      builder = make_search_builder
      builder.search
      expect(document_store).to have_received(:search) do |body|
        expect(body[:_source]).to be(false)
      end
    end

    it "passes the order array as the sort key" do
      builder = make_search_builder
      builder.order.push({ id: { order: "desc" } })
      builder.search
      expect(document_store).to have_received(:search) do |body|
        expect(body[:sort]).to eq([{ id: { order: "desc" } }])
      end
    end

    it "passes a bool query when has_invalid_input is false" do
      builder = make_search_builder
      builder.must.push({ term: { rating: "s" } })
      builder.search
      expect(document_store).to have_received(:search) do |body|
        expect(body[:query]).to have_key(:bool)
      end
    end

    it "passes match_none when has_invalid_input is true" do
      builder = make_search_builder(flag: "banana")
      builder.add_boolean_match(:flag, :is_flagged)
      builder.search
      expect(document_store).to have_received(:search) do |body|
        expect(body[:query]).to eq({ match_none: {} })
      end
    end
  end
end
