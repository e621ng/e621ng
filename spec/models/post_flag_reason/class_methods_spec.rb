# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlagReason do
  include_context "as admin"

  before { PostFlagReason.invalidate_cache }

  describe ".for_radio" do
    it "returns all reasons" do
      reason1 = create(:post_flag_reason, name: "r1", index: 1)
      reason2 = create(:post_flag_reason, name: "r2", index: 2)
      expect(PostFlagReason.for_radio).to include(reason1, reason2)
    end

    it "returns reasons in index ascending order" do
      reason_high = create(:post_flag_reason, name: "high", index: 10)
      reason_low  = create(:post_flag_reason, name: "low",  index: 1)
      result = PostFlagReason.for_radio
      expect(result.index(reason_low)).to be < result.index(reason_high)
    end
  end

  describe ".by_name" do
    it "returns the matching reason" do
      reason = create(:post_flag_reason, name: "findable")
      expect(PostFlagReason.by_name("findable")).to eq(reason)
    end

    it "returns nil for an unknown name" do
      expect(PostFlagReason.by_name("does_not_exist")).to be_nil
    end
  end

  describe ".needs_explanation?" do
    it "returns true when the reason requires an explanation" do
      create(:needs_explanation_post_flag_reason)
      expect(PostFlagReason.needs_explanation?("needs_explanation")).to be true
    end

    it "returns false when the reason does not require an explanation" do
      create(:post_flag_reason)
      expect(PostFlagReason.needs_explanation?("basic")).to be false
    end

    it "returns false for an unknown reason name" do
      expect(PostFlagReason.needs_explanation?("nonexistent")).to be false
    end
  end

  describe ".needs_parent_id?" do
    it "returns true when the reason requires a parent id" do
      create(:needs_parent_id_post_flag_reason)
      expect(PostFlagReason.needs_parent_id?("needs_parent_id")).to be true
    end

    it "returns false when the reason does not require a parent id" do
      create(:post_flag_reason)
      expect(PostFlagReason.needs_parent_id?("basic")).to be false
    end

    it "returns false for an unknown reason name" do
      expect(PostFlagReason.needs_parent_id?("nonexistent")).to be false
    end
  end

  describe "cache invalidation" do
    it "invalidates the cache after save" do
      reason = create(:post_flag_reason, name: "cacheable", reason: "original text")
      PostFlagReason.for_radio # warm cache
      reason.update!(reason: "updated text")
      expect(PostFlagReason.for_radio.find { |r| r.name == "cacheable" }.reason).to eq("updated text")
    end

    it "invalidates the cache after destroy" do
      reason = create(:post_flag_reason, name: "ephemeral")
      PostFlagReason.for_radio # warm cache
      reason.destroy!
      expect(PostFlagReason.for_radio.map(&:name)).not_to include("ephemeral")
    end
  end
end
