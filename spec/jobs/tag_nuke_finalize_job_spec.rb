# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagNukeFinalizeJob do
  include_context "as admin"

  let(:tag) { create(:tag, name: "nuked_tag") }

  before { allow(Post.document_store).to receive(:import) }

  describe "#perform" do
    it "unions and deduplicates the ids across every unapplied undo row" do
      TagRelUndo.create!(tag_rel: tag, undo_data: [101, 102])
      TagRelUndo.create!(tag_rel: tag, undo_data: [102, 103])

      described_class.perform_now(tag.id)
      expect(Post.document_store).to have_received(:import).with(query: { id: [101, 102, 103] })
    end

    it "ignores rows that have already been undone" do
      TagRelUndo.create!(tag_rel: tag, undo_data: [101])
      TagRelUndo.create!(tag_rel: tag, undo_data: [999], applied: true)

      described_class.perform_now(tag.id)
      expect(Post.document_store).to have_received(:import).with(query: { id: [101] })
    end

    it "does not import when the tag has no unapplied undo rows" do
      described_class.perform_now(tag.id)
      expect(Post.document_store).not_to have_received(:import)
    end

    it "unions straggler ids with the undo row ids" do
      TagRelUndo.create!(tag_rel: tag, undo_data: [101, 102])

      described_class.perform_now(tag.id, [102, 103])
      expect(Post.document_store).to have_received(:import).with(query: { id: [101, 102, 103] })
    end

    it "imports stragglers even when no undo rows exist" do
      described_class.perform_now(tag.id, [101])
      expect(Post.document_store).to have_received(:import).with(query: { id: [101] })
    end
  end
end
