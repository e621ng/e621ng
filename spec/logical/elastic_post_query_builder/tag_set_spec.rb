# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_with_set(type, names)
    query = TagQuery.new("solo")
    query.add_tag_set(type, names)
    ElasticPostQueryBuilder.new(query, enable_safe_mode: false)
  end

  it "adds one terms clause per set, in the matching bucket" do
    expect(build_with_set(:must, %w[fox cat]).must).to include({ terms: { tags: %w[fox cat] } })
    expect(build_with_set(:must_not, %w[fox cat]).must_not).to include({ terms: { tags: %w[fox cat] } })
    expect(build_with_set(:should, %w[fox cat]).should).to include({ terms: { tags: %w[fox cat] } })
  end

  it "never emits per-tag term clauses for a set" do
    builder = build_with_set(:must, %w[fox cat])
    expect(builder.must).not_to include({ term: { tags: "fox" } })
  end
end
