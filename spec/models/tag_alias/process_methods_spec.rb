# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # #process!
  # ---------------------------------------------------------------------------

  describe "#process!" do
    it "sets status to active after successful processing" do
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

    it "sets post_count to the consequent tag post_count on success" do
      ta = create(:tag_alias)
      ta.update_columns(status: "queued", approver_id: create(:admin_user).id)
      ta.consequent_tag.update_columns(post_count: 7)

      ta.process!(update_topic: false)

      expect(ta.reload.post_count).to eq(7)
    end
  end

  # ---------------------------------------------------------------------------
  # #process_undo!
  # ---------------------------------------------------------------------------

  describe "#process_undo!" do
    it "resets status to pending" do
      ta = create(:active_tag_alias)
      ta.update_columns(approver_id: create(:admin_user).id)

      ta.process_undo!(update_topic: false)

      expect(ta.reload.status).to eq("pending")
    end

    it "marks all tag_rel_undos as applied" do
      ta = create(:active_tag_alias)
      ta.update_columns(approver_id: create(:admin_user).id)
      ta.tag_rel_undos.create!(undo_data: [])

      ta.process_undo!(update_topic: false)

      expect(ta.tag_rel_undos.where(applied: false).count).to eq(0)
    end

    it "raises when the alias is invalid" do
      ta = create(:active_tag_alias)
      ta.update_columns(approver_id: create(:admin_user).id)
      allow(ta).to receive_messages(
        valid?: false,
        errors: instance_double(ActiveModel::Errors, full_messages: ["something is wrong"]),
      )

      expect { ta.process_undo!(update_topic: false) }.to raise_error(RuntimeError, /something is wrong/)
    end
  end
end
