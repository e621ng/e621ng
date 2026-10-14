# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagRelUndo do
  include_context "as admin"

  # One row per known undo_data format, so the SQL scopes can be checked
  # against the Ruby predicates they mirror.
  let(:parent) { create(:active_tag_alias) }
  let!(:legacy_array)       { parent.tag_rel_undos.create!(undo_data: [1, 2, 3]) }
  let!(:legacy_implication) { parent.tag_rel_undos.create!(undo_data: { "1" => "tag_a tag_b" }) }
  let!(:posts_chunk)        { parent.tag_rel_undos.create!(undo_data: { "version" => 3, "kind" => "posts", "added" => { "1" => %w[tag_a] } }) }
  let!(:side_effects)       { parent.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "side_effects", "alias" => {} }) }

  describe ".legacy_format" do
    it "matches exactly the rows where #legacy? is true" do
      expect(described_class.legacy_format).to match_array(described_class.all.select(&:legacy?))
      expect(described_class.legacy_format).to contain_exactly(legacy_array, legacy_implication)
    end
  end

  describe ".posts_chunks" do
    it "matches exactly the rows where #posts_chunk? is true" do
      expect(described_class.posts_chunks).to match_array(described_class.all.select(&:posts_chunk?))
      expect(described_class.posts_chunks).to contain_exactly(posts_chunk)
    end
  end

  describe ".side_effects_records" do
    it "matches exactly the rows where #side_effects? is true" do
      expect(described_class.side_effects_records).to match_array(described_class.all.select(&:side_effects?))
      expect(described_class.side_effects_records).to contain_exactly(side_effects)
    end
  end

  describe ".unapplied" do
    it "excludes applied rows" do
      posts_chunk.update!(applied: true)
      expect(described_class.unapplied).to contain_exactly(legacy_array, legacy_implication, side_effects)
    end
  end
end
