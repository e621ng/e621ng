# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  describe "required tags of tag-locked sites" do
    include_context "with tag-locked site profile"

    it "cannot be aliased away" do
      record = build(:tag_alias, antecedent_name: "my_little_pony", consequent_name: "pony")
      expect(record).not_to be_valid
      expect(record.errors[:antecedent_name].join).to include("required tag of mlp")
    end

    it "can be aliased to" do
      record = build(:tag_alias, antecedent_name: "mlp", consequent_name: "my_little_pony")
      expect(record).to be_valid
    end

    it "is enforced on BUR alias lines" do
      errors, = BulkUpdateRequestImporter.new("alias my_little_pony -> pony", nil).validate!(CurrentUser.user)
      expect(errors.join).to include("required tag of mlp")
    end

    it "is enforced on BUR nuke lines" do
      errors, = BulkUpdateRequestImporter.new("nuke tag my_little_pony", nil).validate!(CurrentUser.user)
      expect(errors).to eq(["Cannot nuke my_little_pony: required tag of mlp"])
    end
  end

  it "allows aliasing any tag when no site requires it" do
    record = build(:tag_alias, antecedent_name: "my_little_pony", consequent_name: "pony")
    expect(record).to be_valid
  end

  # ---------------------------------------------------------------------------
  # antecedent_name uniqueness (among duplicate_relevant records)
  # ---------------------------------------------------------------------------
  describe "antecedent_name uniqueness" do
    it "is invalid when a pending alias already uses the same antecedent_name" do
      create(:tag_alias, antecedent_name: "duped_ant", consequent_name: "con_one")
      record = build(:tag_alias, antecedent_name: "duped_ant", consequent_name: "con_two")
      expect(record).not_to be_valid
      expect(record.errors[:antecedent_name]).to be_present
    end

    it "is invalid when an active alias already uses the same antecedent_name" do
      create(:active_tag_alias, antecedent_name: "duped_ant", consequent_name: "con_one")
      record = build(:tag_alias, antecedent_name: "duped_ant", consequent_name: "con_two")
      expect(record).not_to be_valid
      expect(record.errors[:antecedent_name]).to be_present
    end

    it "is valid when the only conflicting alias is deleted" do
      existing = create(:tag_alias, antecedent_name: "safe_ant", consequent_name: "con_one")
      existing.update_columns(status: "deleted")
      record = build(:tag_alias, antecedent_name: "safe_ant", consequent_name: "con_two")
      expect(record).to be_valid
    end

    it "skips the uniqueness check when the record itself is deleted" do
      create(:tag_alias, antecedent_name: "shared_ant", consequent_name: "con_one")
      # Force a second alias with the same antecedent into deleted state
      duplicate = create(:tag_alias, antecedent_name: "other_ant", consequent_name: "con_two")
      duplicate.update_columns(antecedent_name: "shared_ant", status: "deleted")
      duplicate.reload
      expect(duplicate).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # antecedent_name tag_name format (TagAlias-specific — shared examples only
  # test consequent_name format)
  # ---------------------------------------------------------------------------
  describe "antecedent_name tag_name format" do
    it "is invalid when antecedent_name starts with a dash" do
      record = build(:tag_alias, antecedent_name: "-bad_tag")
      expect(record).not_to be_valid
      expect(record.errors[:antecedent_name]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # #absence_of_transitive_relation
  # ---------------------------------------------------------------------------
  describe "#absence_of_transitive_relation" do
    it "is invalid when an active alias already uses the consequent_name as its antecedent" do
      create(:active_tag_alias, antecedent_name: "mid_tag", consequent_name: "final_tag")
      record = build(:tag_alias, antecedent_name: "start_tag", consequent_name: "mid_tag")
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("A tag alias for mid_tag already exists")
    end

    it "is valid when the only alias using consequent_name as antecedent is deleted" do
      existing = create(:tag_alias, antecedent_name: "mid_tag", consequent_name: "final_tag")
      existing.update_columns(status: "deleted")
      record = build(:tag_alias, antecedent_name: "start_tag", consequent_name: "mid_tag")
      expect(record).to be_valid
    end

    it "skips the transitive check when the record itself is deleted" do
      create(:active_tag_alias, antecedent_name: "mid_tag", consequent_name: "final_tag")
      record = build(:tag_alias, antecedent_name: "start_tag", consequent_name: "mid_tag", status: "deleted")
      expect(record).to be_valid
    end
  end
end
