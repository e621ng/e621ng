# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagImplicationFinalizeJob do
  include_context "as admin"

  describe "#perform" do
    let(:ti) { create(:tag_implication) }

    before do
      ti.update_columns(status: "active", approver_id: create(:admin_user).id)
      allow(Post.document_store).to receive(:import)
      allow(ti.antecedent_tag).to receive(:fix_post_count)
      allow(ti.consequent_tag).to receive(:fix_post_count)
      allow(TagImplication).to receive(:find_by).with(id: ti.id).and_return(ti)
    end

    it "bulk-reindexes posts matching the given tag name" do
      described_class.perform_now(ti.id, ti.consequent_name)
      expect(Post.document_store).to have_received(:import).with(
        query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", ti.consequent_name],
      )
    end

    it "fixes post counts on both tags after reindexing" do
      described_class.perform_now(ti.id, ti.consequent_name)
      expect(ti.antecedent_tag).to have_received(:fix_post_count)
      expect(ti.consequent_tag).to have_received(:fix_post_count)
    end

    it "uses antecedent_name as the reindex target when called for an undo" do
      described_class.perform_now(ti.id, ti.antecedent_name)
      expect(Post.document_store).to have_received(:import).with(
        query: ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", ti.antecedent_name],
      )
    end
  end
end
