# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Tag::CountMethods                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Tag do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .increment_post_counts
  # -------------------------------------------------------------------------
  describe ".increment_post_counts" do
    it "increments post_count by 1 for each named tag" do
      tag_a = create(:tag, name: "inc_tag_a", post_count: 5)
      tag_b = create(:tag, name: "inc_tag_b", post_count: 0)
      Tag.increment_post_counts(%w[inc_tag_a inc_tag_b])
      expect(tag_a.reload.post_count).to eq(6)
      expect(tag_b.reload.post_count).to eq(1)
    end

    it "does not affect tags not in the list" do
      bystander = create(:tag, name: "inc_bystander", post_count: 3)
      Tag.increment_post_counts(["some_other_tag"])
      expect(bystander.reload.post_count).to eq(3)
    end

    it "is a no-op when passed an empty array" do
      expect { Tag.increment_post_counts([]) }.not_to raise_error
    end
  end

  # -------------------------------------------------------------------------
  # .decrement_post_counts
  # -------------------------------------------------------------------------
  describe ".decrement_post_counts" do
    it "decrements post_count by 1 for each named tag" do
      tag_a = create(:tag, name: "dec_tag_a", post_count: 5)
      tag_b = create(:tag, name: "dec_tag_b", post_count: 2)
      Tag.decrement_post_counts(%w[dec_tag_a dec_tag_b])
      expect(tag_a.reload.post_count).to eq(4)
      expect(tag_b.reload.post_count).to eq(1)
    end

    it "does not affect tags not in the list" do
      bystander = create(:tag, name: "dec_bystander", post_count: 7)
      Tag.decrement_post_counts(["some_other_tag"])
      expect(bystander.reload.post_count).to eq(7)
    end

    it "is a no-op when passed an empty array" do
      expect { Tag.decrement_post_counts([]) }.not_to raise_error
    end
  end

  # -------------------------------------------------------------------------
  # #fix_post_count
  # -------------------------------------------------------------------------
  describe "#fix_post_count" do
    it "updates post_count to the value returned by real_post_count" do
      tag = create(:tag, name: "fix_count_tag", post_count: 99)
      allow(tag).to receive(:real_post_count).and_return(42)
      tag.fix_post_count
      expect(tag.reload.post_count).to eq(42)
    end
  end
end
