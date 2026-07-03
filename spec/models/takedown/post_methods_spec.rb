# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        Takedown PostMethods                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  # Most tests in this file use update_columns to set post_ids / del_post_ids
  # directly, bypassing validate_post_ids (which would strip IDs for non-existent
  # posts). This lets us test the parsing/array helpers independently.
  subject(:takedown) { create(:takedown) }

  include_context "as admin"

  # -------------------------------------------------------------------------
  # matching_post_ids (parsing utility)
  # -------------------------------------------------------------------------
  describe "#matching_post_ids" do
    it "parses bare integer IDs" do
      expect(takedown.matching_post_ids("1 2 3")).to eq([1, 2, 3])
    end

    it "parses full e621.net post URLs" do
      expect(takedown.matching_post_ids("https://e621.net/posts/42")).to eq([42])
    end

    it "parses full e926.net post URLs" do
      expect(takedown.matching_post_ids("https://e926.net/posts/99")).to eq([99])
    end

    it "parses a mix of bare IDs and URLs" do
      result = takedown.matching_post_ids("1 https://e621.net/posts/2 https://e926.net/posts/3")
      expect(result).to contain_exactly(1, 2, 3)
    end

    it "returns an empty array for non-matching text" do
      expect(takedown.matching_post_ids("not_a_post")).to eq([])
    end

    it "deduplicates repeated IDs" do
      expect(takedown.matching_post_ids("5 5 5")).to eq([5])
    end

    # FIXME: Throws an error with nil argument
    # it "returns an empty array for nil" do
    #   expect(takedown.matching_post_ids(nil)).to eq([])
    # end

    it "returns an empty array for empty string" do
      expect(takedown.matching_post_ids("")).to eq([])
    end
  end

  # -------------------------------------------------------------------------
  # post_array
  # -------------------------------------------------------------------------
  describe "#post_array" do
    it "returns parsed IDs from post_ids" do
      takedown.update_columns(post_ids: "10 20 30")
      expect(takedown.post_array).to eq([10, 20, 30])
    end

    it "returns an empty array when post_ids is empty" do
      takedown.update_columns(post_ids: "")
      expect(takedown.post_array).to eq([])
    end
  end

  # -------------------------------------------------------------------------
  # del_post_array
  # -------------------------------------------------------------------------
  describe "#del_post_array" do
    it "returns parsed IDs from del_post_ids" do
      takedown.update_columns(post_ids: "10 20", del_post_ids: "10")
      expect(takedown.del_post_array).to eq([10])
    end

    it "returns an empty array when del_post_ids is empty" do
      takedown.update_columns(del_post_ids: "")
      expect(takedown.del_post_array).to eq([])
    end
  end

  # -------------------------------------------------------------------------
  # kept_post_array
  # -------------------------------------------------------------------------
  describe "#kept_post_array" do
    it "returns IDs that are in post_array but not in del_post_array" do
      takedown.update_columns(post_ids: "1 2 3", del_post_ids: "1")
      expect(takedown.kept_post_array).to contain_exactly(2, 3)
    end

    it "returns all post IDs when none are marked for deletion" do
      takedown.update_columns(post_ids: "1 2 3", del_post_ids: "")
      expect(takedown.kept_post_array).to contain_exactly(1, 2, 3)
    end

    it "returns an empty array when all posts are marked for deletion" do
      takedown.update_columns(post_ids: "1 2", del_post_ids: "1 2")
      expect(takedown.kept_post_array).to eq([])
    end

    it "is memoized — returns the same object on repeated calls" do
      takedown.update_columns(post_ids: "1 2", del_post_ids: "1")
      first = takedown.kept_post_array
      expect(takedown.kept_post_array).to equal(first)
    end
  end

  # -------------------------------------------------------------------------
  # clear_cached_arrays
  # -------------------------------------------------------------------------
  describe "#clear_cached_arrays" do
    it "resets the memoized kept_post_array so changes are reflected" do
      takedown.update_columns(post_ids: "1 2", del_post_ids: "1")
      takedown.kept_post_array # memoizes [2]
      takedown.update_columns(del_post_ids: "1 2")
      # Without clearing, the old value is returned
      takedown.clear_cached_arrays
      expect(takedown.kept_post_array).to eq([])
    end
  end

  # -------------------------------------------------------------------------
  # should_delete
  # -------------------------------------------------------------------------
  describe "#should_delete" do
    before { takedown.update_columns(post_ids: "1 2 3", del_post_ids: "1 3") }

    it "returns true when the ID is in del_post_array" do
      expect(takedown.should_delete(1)).to be true
      expect(takedown.should_delete(3)).to be true
    end

    it "returns false when the ID is not in del_post_array" do
      expect(takedown.should_delete(2)).to be false
    end

    it "returns false for an ID not referenced in the takedown at all" do
      expect(takedown.should_delete(999)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # actual_posts
  # -------------------------------------------------------------------------
  describe "#actual_posts" do
    it "returns Post records matching the IDs in post_array" do
      post = create(:post)
      takedown.update_columns(post_ids: post.id.to_s)
      expect(takedown.actual_posts).to include(post)
    end

    it "returns an empty relation when post_ids is empty" do
      takedown.update_columns(post_ids: "")
      expect(takedown.actual_posts).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # actual_deleted_posts
  # -------------------------------------------------------------------------
  describe "#actual_deleted_posts" do
    it "returns Post records matching the IDs in del_post_array" do
      post = create(:post)
      takedown.update_columns(post_ids: post.id.to_s, del_post_ids: post.id.to_s)
      expect(takedown.actual_deleted_posts).to include(post)
    end

    it "returns an empty relation when del_post_ids is empty" do
      takedown.update_columns(del_post_ids: "")
      expect(takedown.actual_deleted_posts).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # actual_kept_posts
  # -------------------------------------------------------------------------
  describe "#actual_kept_posts" do
    it "returns Post records for IDs in kept_post_array" do
      post_a = create(:post)
      post_b = create(:post)
      takedown.update_columns(
        post_ids:     "#{post_a.id} #{post_b.id}",
        del_post_ids: post_a.id.to_s,
      )
      takedown.clear_cached_arrays
      expect(takedown.actual_kept_posts).to include(post_b)
      expect(takedown.actual_kept_posts).not_to include(post_a)
    end
  end

  # -------------------------------------------------------------------------
  # post_array_was
  # -------------------------------------------------------------------------
  describe "#post_array_was" do
    it "returns the parsed IDs from the post_ids value before the current change" do
      takedown.update_columns(post_ids: "10 20")
      takedown.reload
      takedown.post_ids = "10 20 30"
      expect(takedown.post_array_was).to contain_exactly(10, 20)
    end
  end
end
