# frozen_string_literal: true

require "rails_helper"

# ---------------------------------------------------------------------------
# TagImplication::ApprovalMethods
#
# Covers: approve!, undo!, process!, create_undo_information, update_posts,
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
        .to enqueue_sidekiq_job(TagImplicationJob)
        .and(change { ti.reload.status }.to("queued"))
    end

    it "sets approver_id to the given approver" do
      approver = create(:admin_user)
      expect { ti.approve!(approver: approver, update_topic: false) }
        .to enqueue_sidekiq_job(TagImplicationJob)
        .and(change { ti.reload.approver_id }.to(approver.id))
    end

    it "enqueues TagImplicationJob with the implication id and update_topic flag" do
      expect { ti.approve!(update_topic: false) }
        .to enqueue_sidekiq_job(TagImplicationJob).with(ti.id, false)
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
    it "sets status to active after processing" do
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
        .to enqueue_sidekiq_job(TagImplicationFinalizeJob).with(ti.id, ti.antecedent_name)
    end
  end

  # ---------------------------------------------------------------------------
  # #create_undo_information
  # ---------------------------------------------------------------------------
  describe "#create_undo_information" do
    it "records the predicted added tags for matching posts in a posts chunk" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a")
      ti.update_columns(status: "active")

      ti.create_undo_information

      chunk = ti.tag_rel_undos.find(&:posts_chunk?)
      expect(chunk.undo_data["added"]).to eq(post.id.to_s => ["species_b"])
    end

    it "records the full descendant chain, not just the direct consequent" do
      create(:active_tag_implication, antecedent_name: "species_b", consequent_name: "species_c")
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a")
      ti.update_columns(status: "active")

      ti.create_undo_information

      chunk = ti.tag_rel_undos.find(&:posts_chunk?)
      expect(chunk.undo_data["added"][post.id.to_s]).to match_array(%w[species_b species_c])
    end

    it "excludes tags the post already carries from the added set" do
      create(:active_tag_implication, antecedent_name: "species_b", consequent_name: "species_c")
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a species_c")
      ti.update_columns(status: "active")

      ti.create_undo_information

      chunk = ti.tag_rel_undos.find(&:posts_chunk?)
      expect(chunk.undo_data["added"][post.id.to_s]).to eq(["species_b"])
    end

    it "skips posts that already contain the consequent" do
      ti = create(:active_tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      # Deactivate while creating the post so the implication doesn't auto-apply.
      ti.update_columns(status: "pending")
      post = create(:post, tag_string: "char_a species_b")
      ti.update_columns(status: "active")

      ti.create_undo_information

      recorded_ids = ti.tag_rel_undos.flat_map(&:post_ids)
      expect(recorded_ids).not_to include(post.id)
    end

    it "creates the side effects record last, recording the names at process time" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      create(:post, tag_string: "char_a")
      ti.update_columns(status: "active")

      ti.create_undo_information

      side_effects = ti.tag_rel_undos.order(:id).last
      expect(side_effects.side_effects?).to be(true)
      expect(side_effects.undo_data["implication"]).to eq("antecedent_name" => "char_a", "consequent_name" => "species_b")
    end

    it "creates only the side effects record when no posts match" do
      ti = create(:active_tag_implication)

      expect { ti.create_undo_information }.to change(ti.tag_rel_undos, :count).by(1)
      expect(ti.tag_rel_undos.last.side_effects?).to be(true)
    end

    it "keeps a completed snapshot when run again" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      create(:post, tag_string: "char_a")
      ti.update_columns(status: "active")
      ti.create_undo_information

      expect { ti.create_undo_information }.not_to(change { ti.tag_rel_undos.order(:id).pluck(:id) })
    end

    it "destroys and rebuilds an incomplete snapshot" do
      ti = create(:active_tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      stale = ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => { "123" => ["species_b"] } })

      ti.create_undo_information

      expect(TagRelUndo.exists?(stale.id)).to be(false)
      expect(ti.tag_rel_undos.count).to eq(1)
      expect(ti.tag_rel_undos.last.side_effects?).to be(true)
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
    def create_undoable_implication
      ti = create(:active_tag_implication)
      ti.update_columns(approver_id: create(:admin_user).id)
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => {} })
      ti.tag_rel_undos.create!(undo_data: {
        "version" => 2,
        "kind" => "side_effects",
        "implication" => { "antecedent_name" => ti.antecedent_name, "consequent_name" => ti.consequent_name },
      })
      ti
    end

    it "resets status to pending" do
      ti = create_undoable_implication

      ti.process_undo!(update_topic: false)

      expect(ti.reload.status).to eq("pending")
    end

    it "marks all tag_rel_undos as applied" do
      ti = create_undoable_implication

      ti.process_undo!(update_topic: false)

      expect(ti.tag_rel_undos.where(applied: false).count).to eq(0)
    end

    it "logs a tag_implication_undo mod action" do
      ti = create_undoable_implication

      expect { ti.process_undo!(update_topic: false) }
        .to change { ModAction.where(action: "tag_implication_undo").count }.by(1)
    end

    it "attributes the undo to the undoer, not the original approver" do
      ti = create_undoable_implication
      undoer = create(:admin_user)

      ti.process_undo!(update_topic: false, undoer: undoer)

      expect(ModAction.where(action: "tag_implication_undo").last.creator_id).to eq(undoer.id)
    end

    it "falls back to the original approver when no undoer is given" do
      ti = create_undoable_implication

      ti.process_undo!(update_topic: false)

      expect(ModAction.where(action: "tag_implication_undo").last.creator_id).to eq(ti.approver_id)
    end

    it "calls invalidate_cached_descendants" do
      ti = create_undoable_implication
      allow(ti).to receive(:invalidate_cached_descendants)

      ti.process_undo!(update_topic: false)

      expect(ti).to have_received(:invalidate_cached_descendants)
    end

    it "raises when the implication is invalid" do
      ti = create_undoable_implication
      allow(ti).to receive_messages(
        valid?: false,
        errors: instance_double(ActiveModel::Errors, full_messages: ["something is wrong"]),
      )

      expect { ti.process_undo!(update_topic: false) }.to raise_error(TagImplication::UndoError, /something is wrong/)
    end

    it "raises when the implication is queued or processing" do
      ti = create_undoable_implication
      ti.update_columns(status: "queued")

      expect { ti.process_undo!(update_topic: false) }.to raise_error(TagImplication::UndoError, /cannot be undone while it is/)
    end

    it "resumes an undo that was interrupted after the status was set to pending" do
      ti = create_undoable_implication
      ti.update_columns(status: "pending")

      ti.process_undo!(update_topic: false)

      expect(ti.reload.status).to eq("pending")
      expect(ti.tag_rel_undos.where(applied: false).count).to eq(0)
    end

    it "raises when no unapplied undo information exists" do
      ti = create(:active_tag_implication)
      ti.update_columns(approver_id: create(:admin_user).id)

      expect { ti.process_undo!(update_topic: false) }.to raise_error(TagImplication::UndoError, /No unapplied undo information/)
    end

    it "raises when the undo data is in the legacy array format" do
      ti = create(:active_tag_implication)
      ti.update_columns(approver_id: create(:admin_user).id)
      ti.tag_rel_undos.create!(undo_data: [123, 456])

      expect { ti.process_undo!(update_topic: false) }.to raise_error(TagImplication::UndoError, /predates undo support/)
    end

    it "raises when the undo data is in the legacy tag string format" do
      ti = create(:active_tag_implication)
      ti.update_columns(approver_id: create(:admin_user).id)
      ti.tag_rel_undos.create!(undo_data: { "123" => "char_a" })

      expect { ti.process_undo!(update_topic: false) }.to raise_error(TagImplication::UndoError, /predates undo support/)
    end

    it "raises when the side effects record is missing" do
      ti = create(:active_tag_implication)
      ti.update_columns(approver_id: create(:admin_user).id)
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => {} })

      expect { ti.process_undo!(update_topic: false) }.to raise_error(TagImplication::UndoError, /side effects record is missing/)
    end

    it "raises when the implication was rewritten by an alias after being processed" do
      ti = create_undoable_implication
      # Simulate an alias b -> c moving this one from a -> b to a -> c.
      ti.update_columns(consequent_name: "moved_con_#{SecureRandom.hex(4)}")

      expect { ti.process_undo!(update_topic: false) }.to raise_error(TagImplication::UndoError, /is now #{ti.antecedent_name} -> #{ti.consequent_name}/)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_posts_undo
  # ---------------------------------------------------------------------------
  describe "#update_posts_undo" do
    it "removes the recorded added tags from posts that still carry them" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a species_b")
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => { post.id.to_s => ["species_b"] } })

      ti.update_posts_undo

      expect(post.reload.tag_array).not_to include("species_b")
    end

    it "skips posts that no longer carry any of the recorded tags" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a")
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => { post.id.to_s => ["species_b"] } })

      expect { ti.update_posts_undo }.not_to(change { post.reload.updated_at })
    end

    it "removes only the recorded tags that are still present" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a species_b")
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => { post.id.to_s => %w[species_b species_c] } })

      ti.update_posts_undo

      expect(post.reload.tag_array).to eq(["char_a"])
    end

    it "leaves a tag in place that is still implied by another active implication" do
      create(:active_tag_implication, antecedent_name: "other_char", consequent_name: "species_b")
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      post = create(:post, tag_string: "char_a other_char species_b")
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => { post.id.to_s => ["species_b"] } })

      ti.update_posts_undo

      # The removal is re-applied by normalize_tags during the same save
      # because other_char still implies species_b.
      expect(post.reload.tag_array).to include("species_b")
    end

    it "marks the posts chunk as applied" do
      ti = create(:tag_implication, antecedent_name: "char_a", consequent_name: "species_b")
      chunk = ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => {} })

      ti.update_posts_undo

      expect(chunk.reload.applied).to be(true)
    end

    it "enqueues TagImplicationFinalizeJob with antecedent_name and the undo flag" do
      ti = create(:tag_implication)
      ti.tag_rel_undos.create!(undo_data: { "version" => 2, "kind" => "posts", "added" => {} })

      expect { ti.update_posts_undo }
        .to enqueue_sidekiq_job(TagImplicationFinalizeJob).with(ti.id, ti.antecedent_name, true)
    end
  end

  # ---------------------------------------------------------------------------
  # #undo!
  # ---------------------------------------------------------------------------
  describe "#undo!" do
    it "enqueues TagImplicationUndoJob with the undoing user" do
      ti = create(:active_tag_implication)

      expect { ti.undo! }.to enqueue_sidekiq_job(TagImplicationUndoJob).with(ti.id, true, CurrentUser.user.id)
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
