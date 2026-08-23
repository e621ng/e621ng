# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagBatchJob do
  include_context "as admin"

  def perform(antecedent = "old_tag", consequent = "new_tag")
    described_class.perform_now(antecedent, consequent, CurrentUser.id, CurrentUser.ip_addr)
  end

  describe "#perform" do
    context "when the antecedent contains multiple tags" do
      it "raises JobError" do
        expect { perform("old_tag extra_tag", "new_tag") }.to raise_error(ApplicationJob::JobError)
      end
    end

    context "when the consequent contains multiple tags" do
      it "raises JobError" do
        expect { perform("old_tag", "new_tag extra_tag") }.to raise_error(ApplicationJob::JobError)
      end
    end

    context "with a valid single-tag antecedent and consequent" do
      let!(:post)                { create(:post, tag_string: "old_tag other_tag") }
      let!(:user_with_blacklist) { create(:user, blacklisted_tags: "old_tag") }

      before { perform }

      it "adds the consequent tag to matching posts" do
        expect(post.reload.tag_string).to include("new_tag")
      end

      it "removes the antecedent tag from matching posts" do
        expect(post.reload.tag_string).not_to include("old_tag")
      end

      it "updates blacklists containing the antecedent" do
        expect(user_with_blacklist.reload.blacklisted_tags).to include("new_tag")
      end

      it "does not leave the antecedent in updated blacklists" do
        expect(user_with_blacklist.reload.blacklisted_tags).not_to include("old_tag")
      end

      it "logs a mass_update ModAction" do
        expect(ModAction.last.action).to eq("mass_update")
      end

      it "includes the antecedent and consequent in the ModAction values" do
        expect(ModAction.last[:values]).to include("antecedent" => "old_tag", "consequent" => "new_tag")
      end
    end
  end

  describe "#migrate_posts" do
    let(:job) { described_class.new }

    context "when posts exist with the antecedent tag" do
      let!(:matching_post) { create(:post, tag_string: "old_tag other_tag") }
      let!(:other_post)    { create(:post, tag_string: "unrelated_tag") }

      before { job.migrate_posts("old_tag", "new_tag") }

      it "adds the consequent tag to matching posts" do
        expect(matching_post.reload.tag_string).to include("new_tag")
      end

      it "removes the antecedent tag from matching posts" do
        expect(matching_post.reload.tag_string).not_to include("old_tag")
      end

      it "does not modify posts that do not carry the antecedent tag" do
        expect(other_post.reload.tag_string).to include("unrelated_tag")
        expect(other_post.reload.tag_string).not_to include("new_tag")
      end
    end

    context "when no posts carry the antecedent tag" do
      let!(:other_post) { create(:post, tag_string: "unrelated_tag") }

      it "does not modify any posts" do
        original = other_post.reload.tag_string
        job.migrate_posts("nonexistent_tag", "new_tag")
        expect(other_post.reload.tag_string).to eq(original)
      end
    end
  end

  describe "#migrate_blacklists" do
    let(:job) { described_class.new }

    context "when users have the antecedent in their blacklist" do
      let!(:user_with)    { create(:user, blacklisted_tags: "old_tag\nother_tag") }
      let!(:user_without) { create(:user, blacklisted_tags: "unrelated_tag") }

      before { job.migrate_blacklists("old_tag", "new_tag") }

      it "replaces the antecedent with the consequent in the matching user's blacklist" do
        expect(user_with.reload.blacklisted_tags).to include("new_tag")
        expect(user_with.reload.blacklisted_tags).not_to include("old_tag")
      end

      it "does not insert the consequent into blacklists that did not contain the antecedent" do
        expect(user_without.reload.blacklisted_tags).not_to include("new_tag")
      end

      it "preserves unrelated tags in the updated blacklist" do
        expect(user_with.reload.blacklisted_tags).to include("other_tag")
        expect(user_without.reload.blacklisted_tags).to include("unrelated_tag")
      end
    end
  end

  describe "index reconciliation" do
    let!(:post) { create(:post, tag_string: "old_tag other_tag") }

    it "enqueues the finalize job with the consequent and no stragglers" do
      expect { perform }.to have_enqueued_job(TagBatchFinalizeJob).with("new_tag", [])
    end

    it "does not enqueue the finalize job when the arguments are rejected" do
      expect { perform("old_tag extra_tag", "new_tag") }.to raise_error(ApplicationJob::JobError)
      expect(TagBatchFinalizeJob).not_to have_been_enqueued
    end

    it "still enqueues the finalize job when a post cannot be saved" do
      post.update_columns(rating: "x")
      expect { perform }.to raise_error(ActiveRecord::RecordInvalid)
      expect(TagBatchFinalizeJob).to have_been_enqueued
    end

    it "resolves the consequent through an active alias" do
      create(:tag_alias, antecedent_name: "new_tag", consequent_name: "final_tag", status: "active")
      expect { perform }.to have_enqueued_job(TagBatchFinalizeJob).with("final_tag", [])
      expect(post.reload.tag_array).to include("final_tag")
    end

    it "records posts the consequent did not survive on as stragglers" do
      post.update_columns(locked_tags: "-new_tag")
      expect { perform }.to have_enqueued_job(TagBatchFinalizeJob).with("new_tag", [post.id])
    end

    context "while migrating" do
      # Created before the client is stubbed so the double only sees writes from the loop.
      let(:client) { instance_double(OpenSearch::Client, index: { "result" => "updated" }) }

      before { allow(Post.document_store).to receive(:client).and_return(client) }

      it "does not write posts to the index one at a time" do
        described_class.new.migrate_posts("old_tag", "new_tag")
        expect(client).not_to have_received(:index)
      end
    end

    it "clears the suppression flag once migration succeeds" do
      described_class.new.migrate_posts("old_tag", "new_tag")
      expect(Thread.current[:skip_post_index_update]).to be false
    end

    it "clears the suppression flag when migration raises" do
      post.update_columns(rating: "x")
      expect { described_class.new.migrate_posts("old_tag", "new_tag") }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Thread.current[:skip_post_index_update]).to be false
    end
  end

  describe "#migrate_posts failures" do
    it "raises rather than silently leaving a post on the old tag" do
      broken = create(:post, tag_string: "old_tag")
      broken.update_columns(rating: "x")

      expect { described_class.new.migrate_posts("old_tag", "new_tag") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "keeps the progress it made before the failure" do
      migrated = create(:post, tag_string: "old_tag")
      broken = create(:post, tag_string: "old_tag")
      broken.update_columns(rating: "x")

      expect { described_class.new.migrate_posts("old_tag", "new_tag") }.to raise_error(ActiveRecord::RecordInvalid)
      expect(migrated.reload.tag_array).to include("new_tag")
    end
  end
end
