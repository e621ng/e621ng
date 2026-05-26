# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAliasFinalizeJob do
  include_context "as admin"

  describe "#perform" do
    let(:ta) { create(:tag_alias) }
    let(:post_ids) { [101, 102, 103] }

    before do
      ta.update_columns(status: "active", approver_id: create(:admin_user).id)
      ta.tag_rel_undos.create!(undo_data: post_ids)
      allow(Post.document_store).to receive(:import)
      allow(ta.antecedent_tag).to receive(:fix_post_count)
      allow(ta.consequent_tag).to receive(:fix_post_count) { ta.consequent_tag.post_count = 42 }
      allow(TagAlias).to receive(:find_by).with(id: ta.id).and_return(ta)
    end

    it "reindexes only the posts captured in the undo data" do
      described_class.perform_now(ta.id)
      expect(Post.document_store).to have_received(:import).with(query: { id: post_ids })
    end

    it "unions undo data across multiple tag_rel_undos and de-duplicates" do
      ta.tag_rel_undos.create!(undo_data: [103, 104])
      described_class.perform_now(ta.id)
      expect(Post.document_store).to have_received(:import).with(query: { id: [101, 102, 103, 104] })
    end

    it "skips the bulk reindex when no posts were affected" do
      ta.tag_rel_undos.destroy_all
      described_class.perform_now(ta.id)
      expect(Post.document_store).not_to have_received(:import)
    end

    it "fixes post counts on both tags after reindexing" do
      described_class.perform_now(ta.id)
      expect(ta.antecedent_tag).to have_received(:fix_post_count)
      expect(ta.consequent_tag).to have_received(:fix_post_count)
    end

    it "updates the post count of the tag alias after reindexing" do
      allow(ta).to receive(:update_columns).and_call_original

      described_class.perform_now(ta.id)
      expect(ta).to have_received(:update_columns).with(post_count: 42)
    end
  end
end
