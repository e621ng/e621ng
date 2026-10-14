# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  let(:admin)  { create(:admin_user) }
  let(:member) { create(:user) }

  def create_undoable_alias
    ta = create(:active_tag_alias)
    ta.tag_rel_undos.create!(undo_data: { "version" => 3, "kind" => "posts", "added" => { "1" => %w[tag_a], "2" => %w[tag_b] } })
    ta.tag_rel_undos.create!(undo_data: {
      "version" => 2,
      "kind" => "side_effects",
      "alias" => { "antecedent_name" => ta.antecedent_name, "consequent_name" => ta.consequent_name },
      "relationships" => [],
      "category_change" => nil,
      "artist_change" => nil,
    })
    ta
  end

  # ---------------------------------------------------------------------------
  # #undoable_by?
  # ---------------------------------------------------------------------------

  describe "#undoable_by?" do
    it "returns true for an admin when the alias is undoable" do
      expect(create_undoable_alias.undoable_by?(admin)).to be(true)
    end

    it "returns false for a non-admin even when the alias is undoable" do
      expect(create_undoable_alias.undoable_by?(member)).to be(false)
    end

    it "returns false when the alias is queued" do
      ta = create_undoable_alias
      ta.update_columns(status: "queued")
      expect(ta.undoable_by?(admin)).to be(false)
    end

    it "returns false when the alias is processing" do
      ta = create_undoable_alias
      ta.update_columns(status: "processing")
      expect(ta.undoable_by?(admin)).to be(false)
    end

    it "returns false when the alias is deleted" do
      ta = create_undoable_alias
      ta.update_columns(status: "deleted")
      expect(ta.undoable_by?(admin)).to be(false)
    end

    it "returns false when no undo information exists" do
      expect(create(:active_tag_alias).undoable_by?(admin)).to be(false)
    end

    it "returns false when all undo information is already applied" do
      ta = create_undoable_alias
      ta.tag_rel_undos.update_all(applied: true)
      expect(ta.undoable_by?(admin)).to be(false)
    end

    it "returns false when the undo data is in the legacy format" do
      ta = create(:active_tag_alias)
      ta.tag_rel_undos.create!(undo_data: [[1, 2], [3]])
      expect(ta.undoable_by?(admin)).to be(false)
    end

    it "returns false when the side effects record is missing" do
      ta = create(:active_tag_alias)
      ta.tag_rel_undos.create!(undo_data: { "version" => 3, "kind" => "posts", "added" => {} })
      expect(ta.undoable_by?(admin)).to be(false)
    end

    it "returns false when the alias was rewritten after processing" do
      ta = create_undoable_alias
      ta.update_columns(consequent_name: "rewritten_tag")
      expect(ta.undoable_by?(admin)).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # #undo_post_count
  # ---------------------------------------------------------------------------

  describe "#undo_post_count" do
    it "sums the post counts across all unapplied posts chunks" do
      ta = create_undoable_alias
      ta.tag_rel_undos.create!(undo_data: { "version" => 3, "kind" => "posts", "added" => { "3" => %w[tag_c] } })
      expect(ta.undo_post_count).to eq(3)
    end

    it "ignores applied chunks" do
      ta = create_undoable_alias
      ta.tag_rel_undos.create!(undo_data: { "version" => 3, "kind" => "posts", "added" => { "3" => %w[tag_c] } }, applied: true)
      expect(ta.undo_post_count).to eq(2)
    end

    it "ignores side effects and legacy records" do
      ta = create_undoable_alias
      ta.tag_rel_undos.create!(undo_data: [[4, 5], [6]])
      expect(ta.undo_post_count).to eq(2)
    end

    it "returns 0 when no undo information exists" do
      expect(create(:active_tag_alias).undo_post_count).to eq(0)
    end
  end
end
