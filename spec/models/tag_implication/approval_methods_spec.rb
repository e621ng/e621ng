# frozen_string_literal: true

require "rails_helper"

# ---------------------------------------------------------------------------
# TagImplication::ApprovalMethods
#
# Covers: approve!, process!, create_undo_information, update_posts,
#         process_undo!, update_posts_undo, forum_updater
# ---------------------------------------------------------------------------

RSpec.describe TagImplication do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # #approve!
  # ---------------------------------------------------------------------------
  describe "#approve!" do
    let(:ti) { create(:tag_implication) }

    it "changes status to queued" do
      expect { ti.approve!(update_topic: false) }
        .to have_enqueued_job(TagImplicationJob)
        .and(change { ti.reload.status }.to("queued"))
    end

    it "sets approver_id to the given approver" do
      approver = create(:admin_user)
      expect { ti.approve!(approver: approver, update_topic: false) }
        .to have_enqueued_job(TagImplicationJob)
        .and(change { ti.reload.approver_id }.to(approver.id))
    end

    it "enqueues TagImplicationJob with the implication id and update_topic flag" do
      expect { ti.approve!(update_topic: false) }
        .to have_enqueued_job(TagImplicationJob).with(ti.id, false)
    end

    it "calls invalidate_cached_descendants" do
      allow(ti).to receive(:invalidate_cached_descendants)
      ti.approve!(update_topic: false)
      expect(ti).to have_received(:invalidate_cached_descendants)
    end
  end

  # ---------------------------------------------------------------------------
  # #process!
  # ---------------------------------------------------------------------------
  describe "#process!" do
    it "sets status to active after successful processing" do
      ti = create(:tag_implication)
      ti.update_columns(status: "queued", approver_id: create(:admin_user).id)
      allow(ti).to receive_messages(
        create_undo_information: nil,
        update_posts: nil,
        update_descendant_names_for_parents: nil,
      )

      ti.process!(update_topic: false)

      expect(ti.reload.status).to eq("active")
    end

    it "sets status to error when processing raises an exception" do
      ti = create(:tag_implication)
      ti.update_columns(status: "queued", approver_id: create(:admin_user).id)
      allow(ti).to receive(:create_undo_information).and_raise(RuntimeError, "simulated failure")

      ti.process!(update_topic: false)

      expect(ti.reload.status).to start_with("error:")
    end

    it "enqueues TagImplicationFinalizeJob with antecedent_name on success" do
      ti = create(:tag_implication)
      ti.update_columns(status: "queued", approver_id: create(:admin_user).id)
      allow(ti).to receive_messages(
        create_undo_information: nil,
        update_posts: nil,
        update_descendant_names_for_parents: nil,
      )

      expect { ti.process!(update_topic: false) }
        .to have_enqueued_job(TagImplicationFinalizeJob).with(ti.id, ti.antecedent_name)
    end
  end

  # ---------------------------------------------------------------------------
  # #create_undo_information
  # ---------------------------------------------------------------------------
  describe "#create_undo_information" do
    it "captures matching post tag strings in the undo record" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a")
      ti.update_columns(status: "active")

      ti.create_undo_information

      expect(ti.tag_rel_undos.last.undo_data).to include(post.id.to_s => "char_a")
    end

    it "skips posts that already contain the consequent" do
      ti = create(:active_tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      # Deactivate while creating the post so the implication doesn't auto-apply.
      ti.update_columns(status: "pending")
      post = create(:post, tag_string: "char_a species_b")
      ti.update_columns(status: "active")

      ti.create_undo_information

      recorded_ids = ti.tag_rel_undos.flat_map { |u| u.undo_data.keys.map(&:to_i) }
      expect(recorded_ids).not_to include(post.id)
    end

    it "does not create an undo record when no posts match" do
      ti = create(:active_tag_implication)

      expect { ti.create_undo_information }.not_to change(ti.tag_rel_undos, :count)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_posts
  # ---------------------------------------------------------------------------
  describe "#update_posts" do
    it "applies the implication to matching posts" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a")
      ti.update_columns(status: "active")

      ti.update_posts

      expect(post.reload.tag_array).to include("species_b")
    end

    it "skips posts that already contain the consequent" do
      ti = create(:active_tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      ti.update_columns(status: "pending")
      post = create(:post, tag_string: "char_a species_b")
      ti.update_columns(status: "active")

      expect { ti.update_posts }.not_to(change { post.reload.updated_at })
    end
  end

  # ---------------------------------------------------------------------------
  # #process_undo!
  # ---------------------------------------------------------------------------
  describe "#process_undo!" do
    it "resets status to pending" do
      ti = create(:active_tag_implication)
      ti.update_columns(approver_id: create(:admin_user).id)

      ti.process_undo!(update_topic: false)

      expect(ti.reload.status).to eq("pending")
    end

    it "marks all tag_rel_undos as applied" do
      ti = create(:active_tag_implication)
      ti.update_columns(approver_id: create(:admin_user).id)
      ti.tag_rel_undos.create!(undo_data: {})

      ti.process_undo!(update_topic: false)

      expect(ti.tag_rel_undos.where(applied: false).count).to eq(0)
    end

    it "raises when the implication fails validation" do
      ti = create(:active_tag_implication)
      ti.update_columns(approver_id: create(:admin_user).id)
      allow(ti).to receive_messages(
        valid?: false,
        errors: instance_double(ActiveModel::Errors, full_messages: ["something is wrong"]),
      )

      expect { ti.process_undo!(update_topic: false) }.to raise_error(RuntimeError, /something is wrong/)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_posts_undo
  # ---------------------------------------------------------------------------
  describe "#update_posts_undo" do
    it "removes the consequent tag from posts that did not originally have it" do
      ti = create(:active_tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a species_b")
      # Deactivate so the implication won't re-apply the tag during post save
      ti.update_columns(status: "pending")
      # undo_data records what tags the post had before the implication was applied
      # (only char_a, not species_b), so species_b should be removed
      ti.tag_rel_undos.create!(undo_data: { post.id.to_s => "char_a" }, applied: false)

      ti.update_posts_undo

      expect(post.reload.tag_string.split).not_to include("species_b")
    end

    it "enqueues TagImplicationFinalizeJob with antecedent_name" do
      ti = create(:active_tag_implication)
      ti.update_columns(status: "pending")
      ti.tag_rel_undos.create!(undo_data: {})

      expect { ti.update_posts_undo }
        .to have_enqueued_job(TagImplicationFinalizeJob).with(ti.id, ti.antecedent_name)
    end

    it "skips posts where the consequent was already in the original tag string" do
      ti = create(:active_tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a species_b")
      ti.update_columns(status: "pending")
      # undo_data includes species_b in original tag string — post should not be modified
      ti.tag_rel_undos.create!(undo_data: { post.id.to_s => "char_a species_b" }, applied: false)

      original_tag_string = post.reload.tag_string
      ti.update_posts_undo

      expect(post.reload.tag_string).to eq(original_tag_string)
    end
  end

  # ---------------------------------------------------------------------------
  # #forum_updater
  # ---------------------------------------------------------------------------
  describe "#forum_updater" do
    it "returns a ForumUpdater instance when there is no forum topic" do
      ti = create(:tag_implication)
      expect(ti.forum_updater).to be_a(ForumUpdater)
    end

    it "returns a ForumUpdater instance when a forum topic is present" do
      forum_topic = create(:forum_topic)
      ti = create(:tag_implication)
      ti.update_columns(forum_topic_id: forum_topic.id)
      ti.reload

      expect(ti.forum_updater).to be_a(ForumUpdater)
    end
  end
end
