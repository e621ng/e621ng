# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, **opts)
  end

  describe "safe mode" do
    it "adds a rating:s must clause when enable_safe_mode is true" do
      builder = build_query("", enable_safe_mode: true)
      expect(builder.must).to include({ term: { rating: "s" } })
    end

    it "does not add a rating clause when enable_safe_mode is false" do
      builder = build_query("", enable_safe_mode: false)
      expect(builder.must).not_to include({ term: { rating: "s" } })
    end

    it "infers safe mode from CurrentUser.safe_mode?" do
      allow(CurrentUser).to receive(:safe_mode?).and_return(true)
      builder = ElasticPostQueryBuilder.new("", resolve_aliases: false)
      expect(builder.must).to include({ term: { rating: "s" } })
    end
  end
end
