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

  describe "#process_undo!" do
    def create_undoable_alias
      ta = create(:active_tag_alias)
      ta.update_columns(approver_id: create(:admin_user).id)
      ta.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "with_consequent" => [], "without_consequent" => [] })
      ta.tag_rel_undos.create!(undo_data: {
        "version" => 2,
        "kind" => "side_effects",
        "alias" => { "antecedent_name" => ta.antecedent_name, "consequent_name" => ta.consequent_name },
        "relationships" => [],
        "category_change" => nil,
        "artist_change" => nil,
      })
      ta
    end

    it "resets status to pending" do
      ta = create_undoable_alias

      ta.process_undo!(update_topic: false)

      expect(ta.reload.status).to eq("pending")
    end

    it "marks all tag_rel_undos as applied" do
      ta = create_undoable_alias

      ta.process_undo!(update_topic: false)

      expect(ta.tag_rel_undos.where(applied: false).count).to eq(0)
    end

    it "logs a tag_alias_undo mod action" do
      ta = create_undoable_alias

      expect { ta.process_undo!(update_topic: false) }
        .to change { ModAction.where(action: "tag_alias_undo").count }.by(1)
    end

    it "attributes the undo to the undoer, not the original approver" do
      ta = create_undoable_alias
      undoer = create(:admin_user)

      ta.process_undo!(update_topic: false, undoer: undoer)

      expect(ModAction.where(action: "tag_alias_undo").last.creator_id).to eq(undoer.id)
    end

    it "falls back to the original approver when no undoer is given" do
      ta = create_undoable_alias

      ta.process_undo!(update_topic: false)

      expect(ModAction.where(action: "tag_alias_undo").last.creator_id).to eq(ta.approver_id)
    end

    it "raises when the alias is invalid" do
      ta = create_undoable_alias
      allow(ta).to receive_messages(
        valid?: false,
        errors: instance_double(ActiveModel::Errors, full_messages: ["something is wrong"]),
      )

      expect { ta.process_undo!(update_topic: false) }.to raise_error(TagAlias::UndoError, /something is wrong/)
    end

    it "raises when the alias is neither active nor errored" do
      ta = create_undoable_alias
      ta.update_columns(status: "pending")

      expect { ta.process_undo!(update_topic: false) }.to raise_error(TagAlias::UndoError, /Only active or errored/)
    end

    it "raises when no unapplied undo information exists" do
      ta = create(:active_tag_alias)
      ta.update_columns(approver_id: create(:admin_user).id)

      expect { ta.process_undo!(update_topic: false) }.to raise_error(TagAlias::UndoError, /No unapplied undo information/)
    end

    it "raises when the undo data is in the legacy format" do
      ta = create(:active_tag_alias)
      ta.update_columns(approver_id: create(:admin_user).id)
      ta.tag_rel_undos.create!(undo_data: [123, 456])

      expect { ta.process_undo!(update_topic: false) }.to raise_error(TagAlias::UndoError, /predates undo support/)
    end

    it "raises when the side effects record is missing" do
      ta = create(:active_tag_alias)
      ta.update_columns(approver_id: create(:admin_user).id)
      ta.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "with_consequent" => [], "without_consequent" => [] })

      expect { ta.process_undo!(update_topic: false) }.to raise_error(TagAlias::UndoError, /side effects record is missing/)
    end

    it "raises when the alias was rewritten by a later alias after being processed" do
      ta = create_undoable_alias
      # Simulate a later alias b -> c moving this one from a -> b to a -> c.
      ta.update_columns(consequent_name: "moved_con_#{SecureRandom.hex(4)}")

      expect { ta.process_undo!(update_topic: false) }.to raise_error(TagAlias::UndoError, /is now #{ta.antecedent_name} -> #{ta.consequent_name}/)
    end

    it "raises when the consequent tag is itself actively aliased away" do
      ta = create_undoable_alias
      later = create(:tag_alias, antecedent_name: ta.consequent_name, consequent_name: "later_con_#{SecureRandom.hex(4)}")
      later.update_columns(status: "active")

      # Caught by the alias's own absence_of_transitive_relation validation.
      expect { ta.process_undo!(update_topic: false) }.to raise_error(TagAlias::UndoError, /already exists/)
    end

    it "enqueues TagAliasFinalizeJob" do
      ta = create_undoable_alias

      expect { ta.process_undo!(update_topic: false) }
        .to have_enqueued_job(TagAliasFinalizeJob).with(ta.id)
    end

    it "does not call fix_post_count directly" do
      ta = create_undoable_alias
      allow(ta.antecedent_tag).to receive(:fix_post_count)
      allow(ta.consequent_tag).to receive(:fix_post_count)

      ta.process_undo!(update_topic: false)

      expect(ta.antecedent_tag).not_to have_received(:fix_post_count)
      expect(ta.consequent_tag).not_to have_received(:fix_post_count)
    end
  end

  # ---------------------------------------------------------------------------
  # #undo!
  # ---------------------------------------------------------------------------

  describe "#undo!" do
    it "enqueues TagAliasUndoJob with the undoing user" do
      ta = create(:active_tag_alias)

      expect { ta.undo! }.to have_enqueued_job(TagAliasUndoJob).with(ta.id, true, CurrentUser.user.id)
    end
  end
end
