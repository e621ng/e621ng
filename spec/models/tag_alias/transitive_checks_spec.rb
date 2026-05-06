# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # TransitiveChecks module
  #
  # list_transitives detects two kinds of chains on the record being built:
  #   :alias      — an existing alias whose consequent_name == our antecedent_name
  #   :implication — an existing implication where antecedent_name or
  #                  consequent_name == our antecedent_name
  # ---------------------------------------------------------------------------

  describe "#list_transitives" do
    it "returns an empty array when no chains exist" do
      ta = build(:tag_alias, antecedent_name: "standalone_ant", consequent_name: "standalone_con")
      expect(ta.list_transitives).to be_empty
    end

    it "detects a transitive alias chain (existing alias points to our antecedent)" do
      # first_tag → mid_tag already exists; we're building mid_tag → final_tag
      create(:active_tag_alias, antecedent_name: "first_tag", consequent_name: "mid_tag")
      ta = build(:tag_alias, antecedent_name: "mid_tag", consequent_name: "final_tag")

      transitives = ta.list_transitives
      expect(transitives).not_to be_empty
      expect(transitives.first[0]).to eq(:alias)
    end

    it "detects an implication where our antecedent_name is the implication's antecedent" do
      create(:active_tag_implication, antecedent_name: "ant_tag", consequent_name: "imp_con")
      ta = build(:tag_alias, antecedent_name: "ant_tag", consequent_name: "alias_con")

      transitives = ta.list_transitives
      expect(transitives).not_to be_empty
      expect(transitives.first[0]).to eq(:implication)
    end

    it "detects an implication where our antecedent_name is the implication's consequent" do
      create(:active_tag_implication, antecedent_name: "imp_ant", consequent_name: "ant_tag")
      ta = build(:tag_alias, antecedent_name: "ant_tag", consequent_name: "alias_con")

      transitives = ta.list_transitives
      expect(transitives).not_to be_empty
      expect(transitives.first[0]).to eq(:implication)
    end

    it "ignores deleted aliases when checking for chains" do
      existing = create(:tag_alias, antecedent_name: "first_tag", consequent_name: "mid_tag")
      existing.update_columns(status: "deleted")
      ta = build(:tag_alias, antecedent_name: "mid_tag", consequent_name: "final_tag")

      expect(ta.list_transitives).to be_empty
    end
  end

  describe "#has_transitives" do
    it "returns false when no chains exist" do
      ta = build(:tag_alias, antecedent_name: "clean_ant", consequent_name: "clean_con")
      expect(ta.has_transitives).to be false
    end

    it "returns true when a transitive alias chain exists" do
      create(:active_tag_alias, antecedent_name: "prev_tag", consequent_name: "mid_tag")
      ta = build(:tag_alias, antecedent_name: "mid_tag", consequent_name: "dest_tag")
      expect(ta.has_transitives).to be true
    end
  end
end
