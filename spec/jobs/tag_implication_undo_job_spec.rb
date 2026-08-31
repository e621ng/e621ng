# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagImplicationUndoJob do
  include_context "as admin"

  describe "#perform" do
    let(:tag_implication) { create(:tag_implication) }

    it "calls process_undo! on the tag implication with the undoer" do
      undoer = create(:admin_user)
      allow(TagImplication).to receive(:find).with(tag_implication.id).and_return(tag_implication)
      allow(tag_implication).to receive(:process_undo!)
      described_class.new.perform(tag_implication.id, false, undoer.id)
      expect(tag_implication).to have_received(:process_undo!).with(update_topic: false, undoer: undoer)
    end

    it "passes a nil undoer when none was recorded" do
      allow(TagImplication).to receive(:find).with(tag_implication.id).and_return(tag_implication)
      allow(tag_implication).to receive(:process_undo!)
      described_class.new.perform(tag_implication.id, false)
      expect(tag_implication).to have_received(:process_undo!).with(update_topic: false, undoer: nil)
    end

    it "discards and dmails the undoer when the undo is permanently impossible" do
      undoer = create(:admin_user)
      allow(TagImplication).to receive(:find).with(tag_implication.id).and_return(tag_implication)
      allow(tag_implication).to receive(:process_undo!).and_raise(TagImplication::UndoError, "some permanent problem")

      expect { described_class.new.perform(tag_implication.id, false, undoer.id) }
        .to change { Dmail.where(to_id: undoer.id, owner_id: undoer.id).count }.by(1)

      dmail = Dmail.where(to_id: undoer.id, owner_id: undoer.id).last
      expect(dmail.body).to include("some permanent problem")
    end

    it "discards without notifying when no undoer was recorded" do
      allow(TagImplication).to receive(:find).with(tag_implication.id).and_return(tag_implication)
      allow(tag_implication).to receive(:process_undo!).and_raise(TagImplication::UndoError, "some permanent problem")

      expect { described_class.new.perform(tag_implication.id, false) }.not_to change(Dmail, :count)
    end
  end

  describe ".lock_args" do
    it "locks on the tag implication id only" do
      expect(described_class.lock_args([123, true, 456])).to eq([123])
    end
  end
end
