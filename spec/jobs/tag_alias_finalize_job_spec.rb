# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAliasFinalizeJob do
  include_context "as admin"

  describe "#perform" do
    let(:ta) { create(:tag_alias) }

    before do
      ta.update_columns(status: "active", approver_id: create(:admin_user).id)
      allow(Post.document_store).to receive(:import)
      allow(ta.antecedent_tag).to receive(:fix_post_count)
      allow(ta.consequent_tag).to receive(:fix_post_count)
      allow(TagAlias).to receive(:find_by).with(id: ta.id).and_return(ta)
    end

    it "bulk-reindexes posts matching the given tag name" do
      described_class.perform_now(ta.id, ta.consequent_name)
      expect(Post.document_store).to have_received(:import).with(
        query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", ta.consequent_name],
      )
    end

    it "fixes post counts on both tags after reindexing" do
      described_class.perform_now(ta.id, ta.consequent_name)
      expect(ta.antecedent_tag).to have_received(:fix_post_count)
      expect(ta.consequent_tag).to have_received(:fix_post_count)
    end

    it "uses antecedent_name as the reindex target when called for an undo" do
      described_class.perform_now(ta.id, ta.antecedent_name)
      expect(Post.document_store).to have_received(:import).with(
        query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", ta.antecedent_name],
      )
    end
  end
end
