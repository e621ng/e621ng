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
      it "records no TagRelUndo, since there is nothing to undo or reindex" do
        expect { perform }.not_to change(TagRelUndo, :count)
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

  describe "index reconciliation" do
    let!(:tagged_post) { create(:post, tag_string: "#{tag_name} extra_tag") }

    it "enqueues the finalize job with the tag id" do
      expect { perform }.to have_enqueued_job(TagNukeFinalizeJob).with(tag.id, [])
    end

    it "does not enqueue the finalize job when the tag does not resolve" do
      perform("nonexistent_tag")
      expect(TagNukeFinalizeJob).not_to have_been_enqueued
    end

    it "still enqueues the finalize job when a post cannot be saved" do
      tagged_post.update_columns(rating: "x")
      expect { perform }.to raise_error(ApplicationJob::JobError)
      expect(TagNukeFinalizeJob).to have_been_enqueued
    end

    it "records the undo row even when a post cannot be saved" do
      tagged_post.update_columns(rating: "x")
      expect { perform }.to raise_error(ApplicationJob::JobError)
      expect(TagRelUndo.last.undo_data).to include(tagged_post.id)
    end

    context "while migrating" do
      # tagged_post is created before the client is stubbed so the double only sees writes from the loop.
      let(:client) { instance_double(OpenSearch::Client, index: { "result" => "updated" }) }

      before { allow(Post.document_store).to receive(:client).and_return(client) }

      it "does not write posts to the index one at a time" do
        described_class.new.migrate_posts(tag_name)
        expect(client).not_to have_received(:index)
      end
    end

    it "clears the suppression flag once migration succeeds" do
      described_class.new.migrate_posts(tag_name)
      expect(Thread.current[:skip_post_index_update]).to be false
    end

    it "clears the suppression flag when migration raises" do
      allow(Post).to receive(:sql_raw_tag_match).and_raise(RuntimeError, "boom")
      expect { described_class.new.migrate_posts(tag_name) }.to raise_error(RuntimeError, "boom")
      expect(Thread.current[:skip_post_index_update]).to be false
    end
  end

  describe "failure handling" do
    let!(:broken) { create(:post, tag_string: tag_name).tap { |p| p.update_columns(rating: "x") } }

    it "migrates the posts after a failed one" do
      migrated = create(:post, tag_string: tag_name)
      expect { perform }.to raise_error(ApplicationJob::JobError)
      expect(migrated.reload.tag_array).not_to include(tag_name)
    end

    it "leaves the failed post on the tag so a retry can reattempt it" do
      expect { perform }.to raise_error(ApplicationJob::JobError)
      expect(broken.reload.tag_array).to include(tag_name)
    end

    it "raises a summary naming the skipped posts" do
      expect { perform }.to raise_error(ApplicationJob::JobError, /##{broken.id}/)
    end

    it "does not log a ModAction while posts are failing" do
      expect { perform }.to raise_error(ApplicationJob::JobError)
      expect(ModAction.where(action: "nuke_tag")).not_to exist
    end

    it "fails fast once the failure limit is reached" do
      stub_const("TagNukeJob::FAILURE_LIMIT", 1)
      expect { perform }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "straggler handling" do
    let!(:tagged_post) { create(:post, tag_string: "#{tag_name} extra_tag") }

    it "collects posts missing from the snapshot as stragglers" do
      stragglers = described_class.new.migrate_posts(tag_name, Set.new)
      expect(stragglers).to eq([tagged_post.id])
    end

    it "does not collect posts the snapshot covers" do
      stragglers = described_class.new.migrate_posts(tag_name, Set[tagged_post.id])
      expect(stragglers).to be_empty
    end

    context "when a post gained the tag after the undo snapshot" do
      let(:job) { described_class.new }

      before { allow(job).to receive(:create_undo_information).and_return(Set.new) }

      it "records an undo row for the stragglers" do
        job.perform(tag_name, CurrentUser.id, "127.0.0.1")
        expect(TagRelUndo.last.undo_data).to eq([tagged_post.id])
      end

      it "passes the stragglers to the finalize job" do
        expect { job.perform(tag_name, CurrentUser.id, "127.0.0.1") }.to have_enqueued_job(TagNukeFinalizeJob).with(tag.id, [tagged_post.id])
      end
    end
  end

  describe "#create_undo_information" do
    let(:job) { described_class.new }
    let!(:tagged_post) { create(:post, tag_string: tag_name) }

    it "records the posts carrying the tag" do
      expect { job.create_undo_information(tag) }.to change(TagRelUndo, :count).by(1)
      expect(TagRelUndo.last.undo_data).to eq([tagged_post.id])
    end

    it "does not record again for posts an earlier attempt already captured" do
      job.create_undo_information(tag)
      expect { job.create_undo_information(tag) }.not_to change(TagRelUndo, :count)
    end

    it "records a fresh snapshot once the tag reaches posts no row covers" do
      job.create_undo_information(tag)
      later_post = create(:post, tag_string: tag_name)

      expect { job.create_undo_information(tag) }.to change(TagRelUndo, :count).by(1)
      expect(TagRelUndo.last.undo_data).to contain_exactly(tagged_post.id, later_post.id)
    end

    it "ignores rows from a nuke that has already been undone" do
      TagRelUndo.create!(tag_rel: tag, undo_data: [tagged_post.id], applied: true)
      expect { job.create_undo_information(tag) }.to change(TagRelUndo, :count).by(1)
    end

    it "returns the snapshotted ids" do
      expect(job.create_undo_information(tag)).to eq(Set[tagged_post.id])
    end

    it "includes ids an earlier attempt recorded in the returned snapshot" do
      TagRelUndo.create!(tag_rel: tag, undo_data: [tagged_post.id, 999])
      expect(job.create_undo_information(tag)).to eq(Set[tagged_post.id, 999])
    end
  end
end
