# frozen_string_literal: true

require "rails_helper"

# ---------------------------------------------------------------------------
# TagImplication instance methods
#
# Covers: #dtext_label, #flush_cache, #reload
# ---------------------------------------------------------------------------

RSpec.describe TagImplication do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # #dtext_label
  # ---------------------------------------------------------------------------
  describe "#dtext_label" do
    it "returns the embedded dtext tag for this implication" do
      ti = create(:active_tag_implication)
      expect(ti.dtext_label).to eq("[ti:#{ti.id}]")
    end
  end

  # ---------------------------------------------------------------------------
  # .embedded_pattern (class method)
  # ---------------------------------------------------------------------------
  describe ".embedded_pattern" do
    it "matches a valid embedded tag" do
      expect(TagImplication.embedded_pattern).to match("[ti:42]")
    end

    it "captures the id from the embedded tag" do
      match = TagImplication.embedded_pattern.match("[ti:42]")
      expect(match[:id]).to eq("42")
    end
  end

  # ---------------------------------------------------------------------------
  # #flush_cache
  # ---------------------------------------------------------------------------
  describe "#flush_cache" do
    it "clears the memoized descendants so the next call recomputes them" do
      ti = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      # Prime the memoized value
      original = ti.descendants

      # Add a new link that changes the transitive closure
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")
      ti.flush_cache

      expect(ti.descendants).not_to eq(original)
    end

    it "clears the memoized parents so the next call recomputes them" do
      parent = create(:active_tag_implication, antecedent_name: "tag_root", consequent_name: "tag_mid")
      child  = create(:active_tag_implication, antecedent_name: "tag_mid",  consequent_name: "tag_leaf")
      # Prime the memoized value (empty — no parents for child yet at this point)
      child.parents

      # Add a new parent (grandparent) pointing at tag_mid
      new_parent = create(:active_tag_implication, antecedent_name: "tag_new", consequent_name: "tag_mid")
      child.flush_cache

      expect(child.parents).to include(parent, new_parent)
    end
  end

  # ---------------------------------------------------------------------------
  # #reload
  # ---------------------------------------------------------------------------
  describe "#reload" do
    it "clears the memoized descendants cache on reload" do
      ti = create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      ti.descendants # prime cache
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")

      ti.reload

      expect(ti.descendants).to include("tag_b", "tag_c")
    end
  end
end
