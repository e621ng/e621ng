# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Pool Instance Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe Pool do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #pretty_name
  # -------------------------------------------------------------------------
  describe "#pretty_name" do
    it "replaces underscores with spaces" do
      pool = build(:pool, name: "my_pool_name")
      expect(pool.pretty_name).to eq("my pool name")
    end

    it "returns a name with no underscores unchanged" do
      pool = build(:pool, name: "simplepool")
      expect(pool.pretty_name).to eq("simplepool")
    end
  end

  # -------------------------------------------------------------------------
  # #pretty_category
  # -------------------------------------------------------------------------
  describe "#pretty_category" do
    it "titleizes 'series'" do
      pool = build(:series_pool)
      expect(pool.pretty_category).to eq("Series")
    end

    it "titleizes 'collection'" do
      pool = build(:collection_pool)
      expect(pool.pretty_category).to eq("Collection")
    end
  end

  # -------------------------------------------------------------------------
  # #contains?
  # -------------------------------------------------------------------------
  describe "#contains?" do
    let(:pool) { build(:pool, post_ids: [1, 2, 3]) }

    it "returns true when the post_id is in the list" do
      expect(pool.contains?(2)).to be true
    end

    it "returns false when the post_id is not in the list" do
      expect(pool.contains?(99)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #page_number
  # -------------------------------------------------------------------------
  describe "#page_number" do
    let(:pool) { build(:pool, post_ids: [10, 20, 30]) }

    it "returns 1 for the first post" do
      expect(pool.page_number(10)).to eq(1)
    end

    it "returns the correct 1-based index for a middle post" do
      expect(pool.page_number(20)).to eq(2)
    end

    it "returns 1 for an id not in the pool (index returns nil → 0 + 1)" do
      expect(pool.page_number(99)).to eq(1)
    end
  end

  # -------------------------------------------------------------------------
  # #first_post? / #last_post?
  # -------------------------------------------------------------------------
  describe "#first_post?" do
    let(:pool) { build(:pool, post_ids: [10, 20, 30]) }

    it "returns true for the first post_id" do
      expect(pool.first_post?(10)).to be true
    end

    it "returns false for a non-first post_id" do
      expect(pool.first_post?(20)).to be false
    end
  end

  describe "#last_post?" do
    let(:pool) { build(:pool, post_ids: [10, 20, 30]) }

    it "returns true for the last post_id" do
      expect(pool.last_post?(30)).to be true
    end

    it "returns false for a non-last post_id" do
      expect(pool.last_post?(20)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #previous_post_id / #next_post_id
  # -------------------------------------------------------------------------
  describe "#previous_post_id" do
    let(:pool) { build(:pool, post_ids: [10, 20, 30]) }

    it "returns the previous id for a middle post" do
      expect(pool.previous_post_id(20)).to eq(10)
    end

    it "returns nil for the first post" do
      expect(pool.previous_post_id(10)).to be_nil
    end

    it "returns nil for a post not in the pool" do
      expect(pool.previous_post_id(99)).to be_nil
    end
  end

  describe "#next_post_id" do
    let(:pool) { build(:pool, post_ids: [10, 20, 30]) }

    it "returns the next id for a middle post" do
      expect(pool.next_post_id(20)).to eq(30)
    end

    it "returns nil for the last post" do
      expect(pool.next_post_id(30)).to be_nil
    end

    it "returns nil for a post not in the pool" do
      expect(pool.next_post_id(99)).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # #post_count
  # -------------------------------------------------------------------------
  describe "#post_count" do
    it "returns the number of post_ids" do
      pool = build(:pool, post_ids: [1, 2, 3])
      expect(pool.post_count).to eq(3)
    end

    it "returns 0 when post_ids is empty" do
      pool = build(:pool, post_ids: [])
      expect(pool.post_count).to eq(0)
    end
  end

  # -------------------------------------------------------------------------
  # #last_page
  # -------------------------------------------------------------------------
  describe "#last_page" do
    it "returns ceil(post_count / per_page)" do
      pool = build(:pool, post_ids: (1..25).to_a)
      per_page = CurrentUser.user.per_page
      expected = (25.0 / per_page).ceil
      expect(pool.last_page).to eq(expected)
    end

    it "returns 0 when the pool is empty" do
      pool = build(:pool, post_ids: [])
      expect(pool.last_page).to eq(0)
    end
  end

  # -------------------------------------------------------------------------
  # #deletable_by?
  # -------------------------------------------------------------------------
  describe "#deletable_by?" do
    let(:pool) { build(:pool) }

    it "returns true for a janitor" do
      janitor = create(:janitor_user)
      expect(pool.deletable_by?(janitor)).to be true
    end

    it "returns true for an admin" do
      admin = create(:admin_user)
      expect(pool.deletable_by?(admin)).to be true
    end

    it "returns false for a regular member" do
      member = create(:user)
      expect(pool.deletable_by?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #category_changeable_by?
  # -------------------------------------------------------------------------
  describe "#category_changeable_by?" do
    it "returns true for a janitor regardless of post count" do
      pool = build(:pool, post_ids: (1..100).to_a)
      janitor = create(:janitor_user)
      expect(pool.category_changeable_by?(janitor)).to be true
    end

    it "returns true for a member when post_count is at or below the limit" do
      pool = build(:pool, post_ids: [1])
      member = create(:user)
      expect(pool.category_changeable_by?(member)).to be true
    end

    it "returns false for a member when post_count exceeds the limit" do
      limit = Danbooru.config.pool_category_change_limit
      pool = build(:pool, post_ids: (1..(limit + 1)).to_a)
      member = create(:user)
      expect(pool.category_changeable_by?(member)).to be false
    end

    it "returns true for a member when post_count is exactly at the limit" do
      limit = Danbooru.config.pool_category_change_limit
      pool = build(:pool, post_ids: (1..limit).to_a)
      member = create(:user)
      expect(pool.category_changeable_by?(member)).to be true
    end
  end
end
