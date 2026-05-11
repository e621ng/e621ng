# frozen_string_literal: true

require "rails_helper"

# ---------------------------------------------------------------------------
# TagImplication::DescendantMethods and TagImplication::ParentMethods
#
# DescendantMethods computes and caches the transitive closure of implications.
# ParentMethods finds implications that point at this record's antecedent.
# ---------------------------------------------------------------------------

RSpec.describe TagImplication do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # #descendants (instance)
  # ---------------------------------------------------------------------------
  describe "#descendants" do
    it "returns only the immediate consequent for a standalone implication" do
      ti = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      expect(ti.descendants).to eq(["tag_b"])
    end

    it "returns the transitive closure when a chain exists" do
      # tag_a → tag_b → tag_c
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")
      ti = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      # Reload to clear memoization set during save
      ti.flush_cache
      expect(ti.descendants).to match_array(%w[tag_b tag_c])
    end

    it "ignores non-active implications in the chain" do
      deleted = create(:tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")
      deleted.update_columns(status: "deleted")
      ti = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      ti.flush_cache
      expect(ti.descendants).to eq(["tag_b"])
    end
  end

  # ---------------------------------------------------------------------------
  # #parents (instance)
  # ---------------------------------------------------------------------------
  describe "#parents" do
    it "returns implications whose consequent_name equals this record's antecedent_name" do
      parent = create(:active_tag_implication, antecedent_name: "tag_root", consequent_name: "tag_mid")
      child  = create(:active_tag_implication, antecedent_name: "tag_mid",  consequent_name: "tag_leaf")
      expect(child.parents).to include(parent)
    end

    it "returns only duplicate_relevant records (excludes deleted and retired)" do
      deleted = create(:tag_implication, antecedent_name: "tag_root", consequent_name: "tag_mid")
      deleted.update_columns(status: "deleted")
      child = create(:active_tag_implication, antecedent_name: "tag_mid", consequent_name: "tag_leaf")
      expect(child.parents).not_to include(deleted)
    end

    it "returns an empty collection when no implications point to this antecedent" do
      ti = create(:active_tag_implication, antecedent_name: "orphan_tag", consequent_name: "tag_leaf")
      expect(ti.parents).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # ::with_descendants (class method)
  # ---------------------------------------------------------------------------
  describe "::with_descendants" do
    it "returns the original names unchanged when no active implications exist" do
      expect(TagImplication.with_descendants(["tag_a"])).to include("tag_a")
    end

    it "expands names to include implied tags" do
      create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      result = TagImplication.with_descendants(["tag_a"])
      expect(result).to include("tag_a", "tag_b")
    end

    it "does not duplicate names that appear in both input and descendants" do
      create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      result = TagImplication.with_descendants(%w[tag_a tag_b])
      expect(result.count("tag_b")).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # ::descendants_with_originals (class method)
  # ---------------------------------------------------------------------------
  describe "::descendants_with_originals" do
    it "returns a hash mapping each antecedent to a set of its descendant names" do
      create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      result = TagImplication.descendants_with_originals(["tag_a"])
      expect(result["tag_a"]).to include("tag_b")
    end

    it "returns an empty hash when no active implications match the given names" do
      expect(TagImplication.descendants_with_originals(["unknown_tag"])).to be_empty
    end

    it "ignores non-active implications" do
      ti = create(:tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      ti.update_columns(status: "deleted")
      expect(TagImplication.descendants_with_originals(["tag_a"])).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # #update_descendant_names / before_save hook
  # ---------------------------------------------------------------------------
  describe "#update_descendant_names" do
    it "populates descendant_names with the implication's descendants on save" do
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")
      ti = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      expect(ti.descendant_names).to include("tag_b", "tag_c")
    end
  end

  describe "#update_descendant_names!" do
    it "persists updated descendant_names to the database" do
      ti = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")
      ti.update_descendant_names!
      expect(ti.reload.descendant_names).to include("tag_b", "tag_c")
    end
  end

  # ---------------------------------------------------------------------------
  # #invalidate_cached_descendants
  # ---------------------------------------------------------------------------
  describe "#invalidate_cached_descendants" do
    it "deletes the cache entry for each descendant name" do
      ti = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      allow(Cache).to receive(:delete)

      ti.invalidate_cached_descendants

      expect(Cache).to have_received(:delete).with("descendants-tag_b")
    end

    it "does nothing when descendant_names is empty" do
      ti = create(:active_tag_implication)
      ti.update_columns(descendant_names: [])
      allow(Cache).to receive(:delete)

      ti.invalidate_cached_descendants

      expect(Cache).not_to have_received(:delete)
    end
  end

  # ---------------------------------------------------------------------------
  # ::cached_descendants (class method)
  # ---------------------------------------------------------------------------
  describe "::cached_descendants" do
    it "returns antecedent names whose descendant_names include the given tag" do
      create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      expect(TagImplication.cached_descendants("tag_b")).to include("tag_a")
    end

    it "returns an empty array when no active implications have the tag as a descendant" do
      expect(TagImplication.cached_descendants("unknown_tag")).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # Circular detection in #update_descendant_names_for_parents
  # ---------------------------------------------------------------------------
  describe "#update_descendant_names_for_parents circular detection" do
    it "marks a parent as errored when its id is already in the visited set" do
      parent = create(:active_tag_implication, antecedent_name: "tag_x", consequent_name: "tag_a")
      child  = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      # parent.consequent_name == child.antecedent_name, so parent is in child's parents chain.
      # Passing parent.id in the visited set simulates a previously-traversed ancestor,
      # directly exercising the circular-detection error branch without needing a real
      # circular implication in the DB (which would cause an infinite loop in #descendants).
      child.update_descendant_names_for_parents(Set.new([parent.id]))

      expect(parent.reload.status).to eq("error: circular implication detected")
    end
  end
end
