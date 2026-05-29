# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # #process!
  # ---------------------------------------------------------------------------

  describe "#process!" do
    it "sets status to active after processing" do
      ta = create(:tag_alias)
      ta.update_columns(status: "queued", approver_id: create(:admin_user).id)

      ta.process!(update_topic: false)

      expect(ta.reload.status).to eq("active")
    end

    it "sets status to error when processing raises an exception" do
      ta = create(:tag_alias)
      ta.update_columns(status: "queued", approver_id: create(:admin_user).id)
      allow(ta).to receive(:create_undo_information).and_raise(RuntimeError, "simulated failure")

      ta.process!(update_topic: false)

      expect(ta.reload.status).to start_with("error:")
    end

    it "enqueues TagAliasFinalizeJob on success" do
      ta = create(:tag_alias)
      ta.update_columns(status: "queued", approver_id: create(:admin_user).id)

      expect { ta.process!(update_topic: false) }
        .to have_enqueued_job(TagAliasFinalizeJob).with(ta.id)
    end

    it "enqueues TagAliasFinalizeJob even when processing fails so partially-modified posts get reindexed" do
      ta = create(:tag_alias)
      ta.update_columns(status: "queued", approver_id: create(:admin_user).id)
      allow(ta).to receive(:update_posts).and_raise(RuntimeError, "simulated failure")

      expect { ta.process!(update_topic: false) }
        .to have_enqueued_job(TagAliasFinalizeJob).with(ta.id)
      expect(ta.reload.status).to start_with("error:")
    end

    it "does not call fix_post_count directly" do
      ta = create(:tag_alias)
      ta.update_columns(status: "queued", approver_id: create(:admin_user).id)
      allow(ta.antecedent_tag).to receive(:fix_post_count)
      allow(ta.consequent_tag).to receive(:fix_post_count)

      ta.process!(update_topic: false)

      expect(ta.antecedent_tag).not_to have_received(:fix_post_count)
      expect(ta.consequent_tag).not_to have_received(:fix_post_count)
    end
  end

  # ---------------------------------------------------------------------------
  # #process_undo!
  # ---------------------------------------------------------------------------

  # describe "#process_undo!" do
  #   it "resets status to pending" do
  #     ta = create(:active_tag_alias)
  #     ta.update_columns(approver_id: create(:admin_user).id)
  #
  #     ta.process_undo!(update_topic: false)
  #
  #     expect(ta.reload.status).to eq("pending")
  #   end
  #
  #   it "marks all tag_rel_undos as applied" do
  #     ta = create(:active_tag_alias)
  #     ta.update_columns(approver_id: create(:admin_user).id)
  #     ta.tag_rel_undos.create!(undo_data: [])
  #
  #     ta.process_undo!(update_topic: false)
  #
  #     expect(ta.tag_rel_undos.where(applied: false).count).to eq(0)
  #   end
  #
  #   it "raises when the alias is invalid" do
  #     ta = create(:active_tag_alias)
  #     ta.update_columns(approver_id: create(:admin_user).id)
  #     allow(ta).to receive_messages(
  #       valid?: false,
  #       errors: instance_double(ActiveModel::Errors, full_messages: ["something is wrong"]),
  #     )
  #
  #     expect { ta.process_undo!(update_topic: false) }.to raise_error(RuntimeError, /something is wrong/)
  #   end
  #
  #   it "enqueues TagAliasFinalizeJob with antecedent_name" do
  #     ta = create(:active_tag_alias)
  #     ta.update_columns(approver_id: create(:admin_user).id)
  #
  #     expect { ta.process_undo!(update_topic: false) }
  #       .to have_enqueued_job(TagAliasFinalizeJob).with(ta.id, ta.antecedent_name)
  #   end
  #
  #   it "does not call fix_post_count directly" do
  #     ta = create(:active_tag_alias)
  #     ta.update_columns(approver_id: create(:admin_user).id)
  #     allow(ta.antecedent_tag).to receive(:fix_post_count)
  #     allow(ta.consequent_tag).to receive(:fix_post_count)
  #
  #     ta.process_undo!(update_topic: false)
  #
  #     expect(ta.antecedent_tag).not_to have_received(:fix_post_count)
  #     expect(ta.consequent_tag).not_to have_received(:fix_post_count)
  #   end
  # end
end
