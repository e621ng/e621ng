# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "CAN_HAVE_GROUPS" do
    it "is false" do
      expect(described_class::CAN_HAVE_GROUPS).to be false
    end
  end

  describe "#search" do
    it "returns an ActiveRecord relation" do
      expect(run("")).to be_a(ActiveRecord::Relation)
    end

    it "accepts a pre-built TagQuery object" do
      post = create(:post)
      tq = TagQuery.new("")
      result = PostQueryBuilder.new(tq).search
      expect(result).to include(post)
    end

    it "returns all posts for an empty query" do
      post_a = create(:post)
      post_b = create(:post)
      result = run("")
      expect(result).to include(post_a, post_b)
    end
  end
end
