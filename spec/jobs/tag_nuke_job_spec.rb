# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagNukeJob do
  include_context "as admin"

  let(:tag_name) { "nuke_target" }
  let!(:tag) { create(:tag, name: tag_name) }

  def perform(name = tag_name, updater_id = CurrentUser.id, ip = "127.0.0.1")
    described_class.perform_now(name, updater_id, ip)
  end

  describe "#perform" do
    context "when the tag does not exist" do
      it "returns without error" do
        expect { perform("nonexistent_tag") }.not_to raise_error
      end

      it "does not create any TagRelUndo records" do
        expect { perform("nonexistent_tag") }.not_to change(TagRelUndo, :count)
      end

      it "does not log a ModAction" do
        expect { perform("nonexistent_tag") }.not_to change(ModAction, :count)
      end
    end

    context "when the tag exists but has no posts" do
      it "creates a TagRelUndo record with empty undo_data" do
        expect { perform }.to change(TagRelUndo, :count).by(1)
        expect(TagRelUndo.last.undo_data).to eq([])
      end

      it "logs a nuke_tag ModAction" do
        perform
        expect(ModAction.last.action).to eq("nuke_tag")
        expect(ModAction.last[:values]).to include("tag_name" => tag_name)
      end
    end

    context "when the tag exists and posts match" do
      let!(:post_with_tag)    { create(:post, tag_string: "#{tag_name} extra_tag") }
      let!(:post_without_tag) { create(:post) }

      it "removes the tag from all matching posts" do
        perform
        expect(post_with_tag.reload.tag_array).not_to include(tag_name)
      end

      it "preserves other tags on the matching post" do
        perform
        expect(post_with_tag.reload.tag_array).to include("extra_tag")
      end

      it "does not modify posts that did not have the tag" do
        original_tags = post_without_tag.tag_array.dup
        perform
        expect(post_without_tag.reload.tag_array).to match_array(original_tags)
      end

      it "creates a TagRelUndo whose undo_data includes the matching post ID" do
        perform
        expect(TagRelUndo.last.undo_data).to include(post_with_tag.id)
      end

      it "creates a TagRelUndo whose undo_data excludes non-matching post IDs" do
        perform
        expect(TagRelUndo.last.undo_data).not_to include(post_without_tag.id)
      end

      it "associates the TagRelUndo with the nuked tag" do
        perform
        expect(TagRelUndo.last.tag_rel).to eq(tag)
      end

      it "logs a nuke_tag ModAction" do
        perform
        expect(ModAction.last.action).to eq("nuke_tag")
        expect(ModAction.last[:values]).to include("tag_name" => tag_name)
      end
    end
  end

  describe ".process_undo!" do
    let!(:post) { create(:post) }

    context "when unapplied TagRelUndo records exist" do
      let!(:tag_rel_undo) { TagRelUndo.create!(tag_rel: tag, undo_data: [post.id], applied: false) }

      it "adds the tag back to the posts listed in undo_data" do
        described_class.process_undo!(tag)
        expect(post.reload.tag_array).to include(tag_name)
      end

      it "marks the TagRelUndo record as applied" do
        described_class.process_undo!(tag)
        expect(tag_rel_undo.reload.applied).to be true
      end
    end

    context "when TagRelUndo records are already applied" do
      before { TagRelUndo.create!(tag_rel: tag, undo_data: [post.id], applied: true) }

      it "does not add the tag to posts" do
        described_class.process_undo!(tag)
        expect(post.reload.tag_array).not_to include(tag_name)
      end
    end

    context "when no TagRelUndo records exist for the tag" do
      it "does not raise an error" do
        expect { described_class.process_undo!(tag) }.not_to raise_error
      end
    end
  end
end
