# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagImplication do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # antecedent_name uniqueness (scoped to consequent_name, among duplicate_relevant)
  #
  # Unlike TagAlias (unique on antecedent alone), TagImplication only rejects
  # duplicates when both antecedent_name AND consequent_name are the same.
  # ---------------------------------------------------------------------------
  describe "antecedent_name uniqueness" do
    it "is invalid when a pending implication with the same antecedent+consequent already exists" do
      create(:tag_implication, antecedent_name: "duped_ant", consequent_name: "duped_con")
      record = build(:tag_implication, antecedent_name: "duped_ant", consequent_name: "duped_con")
      expect(record).not_to be_valid
      expect(record.errors[:antecedent_name]).to be_present
    end

    it "is invalid when an active implication with the same antecedent+consequent already exists" do
      create(:active_tag_implication, antecedent_name: "duped_ant", consequent_name: "duped_con")
      record = build(:tag_implication, antecedent_name: "duped_ant", consequent_name: "duped_con")
      expect(record).not_to be_valid
      expect(record.errors[:antecedent_name]).to be_present
    end

    it "is valid when the same antecedent maps to a different consequent" do
      create(:tag_implication, antecedent_name: "shared_ant", consequent_name: "con_one")
      record = build(:tag_implication, antecedent_name: "shared_ant", consequent_name: "con_two")
      expect(record).to be_valid
    end

    it "is valid when the only conflicting implication is deleted" do
      existing = create(:tag_implication, antecedent_name: "safe_ant", consequent_name: "safe_con")
      existing.update_columns(status: "deleted")
      record = build(:tag_implication, antecedent_name: "safe_ant", consequent_name: "safe_con")
      expect(record).to be_valid
    end

    it "skips the uniqueness check when the record itself is deleted" do
      create(:tag_implication, antecedent_name: "shared_ant", consequent_name: "shared_con")
      duplicate = create(:tag_implication, antecedent_name: "other_ant", consequent_name: "other_con")
      duplicate.update_columns(antecedent_name: "shared_ant", consequent_name: "shared_con", status: "deleted")
      duplicate.reload
      expect(duplicate).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # antecedent_name tag_name format
  # ---------------------------------------------------------------------------
  describe "antecedent_name tag_name format" do
    it "is invalid when antecedent_name starts with a dash" do
      record = build(:tag_implication, antecedent_name: "-bad_tag")
      expect(record).not_to be_valid
      expect(record.errors[:antecedent_name]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # #absence_of_circular_relation
  # ---------------------------------------------------------------------------
  describe "#absence_of_circular_relation" do
    it "is invalid when the implication would create a direct cycle (a→b already implies b→a)" do
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_a")
      record = build(:tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("Tag implication can not create a circular relation with another tag implication")
    end

    it "is valid when there is no circular dependency" do
      record = build(:tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      expect(record).to be_valid
    end

    it "skips the circular check when the record itself is deleted" do
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_a")
      record = build(:tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b", status: "deleted")
      expect(record).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # #absence_of_transitive_relation
  #
  # If a→b and b→c are active, then a→c is redundant (transitive) and invalid.
  # ---------------------------------------------------------------------------
  describe "#absence_of_transitive_relation" do
    it "is invalid when the consequent is already implied transitively by the antecedent" do
      # a→b→c: trying to add a→c should fail
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")
      create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      # At this point a_to_b.descendant_names should include tag_c via b_to_c
      record = build(:tag_implication, antecedent_name: "tag_a", consequent_name: "tag_c")
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("tag_a already implies tag_c through another implication")
    end

    it "is valid when the transitive chain only involves deleted implications" do
      b_to_c = create(:tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")
      b_to_c.update_columns(status: "deleted")
      create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      record = build(:tag_implication, antecedent_name: "tag_a", consequent_name: "tag_c")
      expect(record).to be_valid
    end

    it "skips the transitive check when the record itself is deleted" do
      create(:active_tag_implication, antecedent_name: "tag_b", consequent_name: "tag_c")
      create(:active_tag_implication, antecedent_name: "tag_a", consequent_name: "tag_b")
      record = build(:tag_implication, antecedent_name: "tag_a", consequent_name: "tag_c", status: "deleted")
      expect(record).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # #antecedent_is_not_aliased
  # ---------------------------------------------------------------------------
  describe "#antecedent_is_not_aliased" do
    it "is invalid when the antecedent_name is the antecedent of an active tag alias" do
      create(:active_tag_alias, antecedent_name: "aliased_tag", consequent_name: "canonical_tag")
      record = build(:tag_implication, antecedent_name: "aliased_tag")
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("Antecedent tag must not be aliased to another tag")
    end

    it "is valid when the antecedent alias is deleted" do
      ta = create(:tag_alias, antecedent_name: "formerly_aliased", consequent_name: "canonical_tag")
      ta.update_columns(status: "deleted")
      record = build(:tag_implication, antecedent_name: "formerly_aliased")
      expect(record).to be_valid
    end

    it "skips the alias check when the record itself is deleted" do
      create(:active_tag_alias, antecedent_name: "aliased_tag", consequent_name: "canonical_tag")
      record = build(:tag_implication, antecedent_name: "aliased_tag", status: "deleted")
      expect(record).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # #consequent_is_not_aliased
  # ---------------------------------------------------------------------------
  describe "#consequent_is_not_aliased" do
    it "is invalid when the consequent_name is the antecedent of an active tag alias" do
      create(:active_tag_alias, antecedent_name: "aliased_target", consequent_name: "canonical_tag")
      record = build(:tag_implication, consequent_name: "aliased_target")
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("Consequent tag must not be aliased to another tag")
    end

    it "is valid when the consequent alias is deleted" do
      ta = create(:tag_alias, antecedent_name: "formerly_aliased_target", consequent_name: "canonical_tag")
      ta.update_columns(status: "deleted")
      record = build(:tag_implication, consequent_name: "formerly_aliased_target")
      expect(record).to be_valid
    end

    it "skips the alias check when the record itself is deleted" do
      create(:active_tag_alias, antecedent_name: "aliased_target", consequent_name: "canonical_tag")
      record = build(:tag_implication, consequent_name: "aliased_target", status: "deleted")
      expect(record).to be_valid
    end
  end
end
