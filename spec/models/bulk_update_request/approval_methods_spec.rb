# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequest do
  include_context "as admin"

  let(:approver) { create(:admin_user) }

  # ---------------------------------------------------------------------------
  # #approve! — happy path (create alias)
  # ---------------------------------------------------------------------------
  describe "#approve! with a create_alias script" do
    let(:bur) { create(:bulk_update_request, script: "alias approve_ant -> approve_con") }

    it "changes status to approved" do
      expect { bur.approve!(approver) }.to change { bur.reload.status }.from("pending").to("approved")
    end

    it "sets the approver" do
      bur.approve!(approver)
      expect(bur.reload.approver).to eq(approver)
    end

    it "creates a TagAlias record for the alias pair" do
      bur.approve!(approver)
      expect(TagAlias.where(antecedent_name: "approve_ant", consequent_name: "approve_con")).to exist
    end

    it "enqueues a TagAliasJob" do
      expect { bur.approve!(approver) }.to have_enqueued_job(TagAliasJob)
    end
  end

  # ---------------------------------------------------------------------------
  # #approve! — happy path (create implication)
  # ---------------------------------------------------------------------------
  describe "#approve! with a create_implication script" do
    let(:bur) { create(:bulk_update_request, script: "implicate imp_ant -> imp_con") }

    it "changes status to approved" do
      expect { bur.approve!(approver) }.to change { bur.reload.status }.from("pending").to("approved")
    end

    it "creates a TagImplication record" do
      bur.approve!(approver)
      expect(TagImplication.where(antecedent_name: "imp_ant", consequent_name: "imp_con")).to exist
    end

    it "enqueues a TagImplicationJob" do
      expect { bur.approve!(approver) }.to have_enqueued_job(TagImplicationJob)
    end
  end

  # ---------------------------------------------------------------------------
  # #approve! — failure path
  # ---------------------------------------------------------------------------
  describe "#approve! when the importer raises an error" do
    def create_bur_with_failing_importer
      bur = create(:bulk_update_request)
      importer_double = instance_double(BulkUpdateRequestImporter)
      allow(BulkUpdateRequestImporter).to receive(:new).and_return(importer_double)
      allow(importer_double).to receive(:process!).and_raise(BulkUpdateRequestImporter::Error, "test failure")
      bur
    end

    it "adds an error to errors[:base]" do
      bur = create_bur_with_failing_importer
      bur.approve!(approver)
      expect(bur.errors[:base]).to include("test failure")
    end

    it "does not change status to approved" do
      bur = create_bur_with_failing_importer
      bur.approve!(approver)
      expect(bur.reload.status).to eq("pending")
    end
  end

  # ---------------------------------------------------------------------------
  # #reject!
  # ---------------------------------------------------------------------------
  describe "#reject!" do
    let(:bur) { create(:bulk_update_request) }

    it "changes status to rejected" do
      expect { bur.reject! }.to change { bur.reload.status }.from("pending").to("rejected")
    end

    it "does not set an approver" do
      bur.reject!
      expect(bur.reload.approver_id).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # #create_forum_topic (after_create callback)
  # ---------------------------------------------------------------------------
  describe "#create_forum_topic" do
    it "does not create a forum topic when skip_forum is true" do
      bur = create(:bulk_update_request, skip_forum: true)
      expect(bur.forum_topic_id).to be_nil
      expect(bur.forum_post_id).to be_nil
    end

    it "creates a new ForumTopic and assigns forum_topic_id and forum_post_id when skip_forum is false" do
      bur = create(:bulk_update_request, skip_forum: false, reason: "A valid reason for this BUR")
      bur.reload
      expect(bur.forum_topic_id).to be_present
      expect(bur.forum_post_id).to be_present
      expect(ForumTopic.find(bur.forum_topic_id)).to be_present
    end

    it "creates a ForumPost on an existing topic when forum_topic_id is provided and skip_forum is false" do
      topic = create(:forum_topic)
      bur = create(:bulk_update_request, forum_topic_id: topic.id, skip_forum: false, reason: "A valid reason for this BUR")
      bur.reload
      expect(bur.forum_topic_id).to eq(topic.id)
      expect(bur.forum_post_id).to be_present
    end
  end
end
