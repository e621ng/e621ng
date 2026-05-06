# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         PostSet Post Methods                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostSet do
  include_context "as member"

  # Use a fixed ID list; populate via update_columns to bypass synchronize callback.
  let(:ids) { [10, 20, 30, 40, 50] }
  let(:set) do
    s = create(:post_set)
    s.update_columns(post_ids: ids, post_count: ids.size)
    s.reload
  end

  # -------------------------------------------------------------------------
  # #max_posts / #capacity
  # -------------------------------------------------------------------------
  describe "#max_posts" do
    it "returns the configured post_set_post_limit" do
      expect(set.max_posts).to eq(Danbooru.config.post_set_post_limit.to_i)
    end
  end

  describe "#capacity" do
    it "returns max_posts minus current post_count" do
      max = set.max_posts
      expect(set.capacity).to eq(max - ids.size)
    end
  end

  # -------------------------------------------------------------------------
  # #contains?
  # -------------------------------------------------------------------------
  describe "#contains?" do
    it "returns true for a post_id present in the set" do
      expect(set.contains?(20)).to be true
    end

    it "returns false for a post_id not in the set" do
      expect(set.contains?(999)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #page_number
  # -------------------------------------------------------------------------
  describe "#page_number" do
    it "returns 1-based position of the post_id in the set" do
      expect(set.page_number(10)).to eq(1)
      expect(set.page_number(30)).to eq(3)
      expect(set.page_number(50)).to eq(5)
    end

    it "returns 1 when the post_id is not in the set (index returns nil → 0 + 1)" do
      expect(set.page_number(999)).to eq(1)
    end
  end

  # -------------------------------------------------------------------------
  # #first_post? / #last_post?
  # -------------------------------------------------------------------------
  describe "#first_post?" do
    it "returns true for the first post_id" do
      expect(set.first_post?(10)).to be true
    end

    it "returns false for a non-first post_id" do
      expect(set.first_post?(20)).to be false
    end
  end

  describe "#last_post?" do
    it "returns true for the last post_id" do
      expect(set.last_post?(50)).to be true
    end

    it "returns false for a non-last post_id" do
      expect(set.last_post?(10)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #previous_post_id
  # -------------------------------------------------------------------------
  describe "#previous_post_id" do
    it "returns the preceding post_id" do
      expect(set.previous_post_id(30)).to eq(20)
    end

    it "returns nil for the first post_id" do
      expect(set.previous_post_id(10)).to be_nil
    end

    it "returns nil for a post_id not in the set" do
      expect(set.previous_post_id(999)).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # #next_post_id
  # -------------------------------------------------------------------------
  describe "#next_post_id" do
    it "returns the following post_id" do
      expect(set.next_post_id(30)).to eq(40)
    end

    it "returns nil for the last post_id" do
      expect(set.next_post_id(50)).to be_nil
    end

    it "returns nil for a post_id not in the set" do
      expect(set.next_post_id(999)).to be_nil
    end
  end
end
