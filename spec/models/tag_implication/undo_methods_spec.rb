# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagImplication do
  include_context "as admin"

  let(:admin)  { create(:admin_user) }
  let(:member) { create(:user) }

  def create_undoable_implication
    ti = create(:active_tag_implication)
    ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => { "1" => %w[tag_a], "2" => %w[tag_b] } })
    ti.tag_rel_undos.create!(undo_data: {
      "version" => 2,
      "kind" => "side_effects",
      "implication" => { "antecedent_name" => ti.antecedent_name, "consequent_name" => ti.consequent_name },
    })
    ti
  end

  describe "#undoable_by?" do
    it "returns true for an admin when the implication is undoable" do
      expect(create_undoable_implication.undoable_by?(admin)).to be(true)
    end

    it "returns false for a non-admin even when the implication is undoable" do
      expect(create_undoable_implication.undoable_by?(member)).to be(false)
    end

    it "returns false when no undo information exists" do
      expect(create(:active_tag_implication).undoable_by?(admin)).to be(false)
    end

    it "returns false when the side effects record is missing" do
      ti = create(:active_tag_implication)
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => {} })
      expect(ti.undoable_by?(admin)).to be(false)
    end
  end

  describe "#undo_post_count" do
    it "sums the post counts across all unapplied posts chunks" do
      ti = create_undoable_implication
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => { "3" => %w[tag_c] } })
      expect(ti.undo_post_count).to eq(3)
    end

    it "ignores applied chunks and non-posts records" do
      ti = create_undoable_implication
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => { "3" => %w[tag_c] } }, applied: true)
      expect(ti.undo_post_count).to eq(2)
    end

    it "returns 0 when no undo information exists" do
      expect(create(:active_tag_implication).undo_post_count).to eq(0)
    end
  end
end
