# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAliasUndoJob do
  include_context "as admin"

  describe "#perform" do
    let(:tag_alias) { create(:tag_alias) }

    it "calls process_undo! on the tag alias with the undoer" do
      undoer = create(:admin_user)
      allow(TagAlias).to receive(:find).with(tag_alias.id).and_return(tag_alias)
      allow(tag_alias).to receive(:process_undo!)
      described_class.perform_now(tag_alias.id, false, undoer.id)
      expect(tag_alias).to have_received(:process_undo!).with(update_topic: false, undoer: undoer)
    end

    it "passes a nil undoer when none was recorded" do
      allow(TagAlias).to receive(:find).with(tag_alias.id).and_return(tag_alias)
      allow(tag_alias).to receive(:process_undo!)
      described_class.perform_now(tag_alias.id, false)
      expect(tag_alias).to have_received(:process_undo!).with(update_topic: false, undoer: nil)
    end
  end

  describe ".lock_args" do
    it "locks on the tag alias id only" do
      expect(described_class.lock_args([123, true, 456])).to eq([123])
    end
  end
end
