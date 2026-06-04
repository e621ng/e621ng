# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  subject(:post) { create(:post) }

  include_context "as admin"

  def deleted_events(record)
    PostEvent.where(post_id: record.id, action: "deleted").count
  end

  def undeleted_events(record)
    PostEvent.where(post_id: record.id, action: "undeleted").count
  end

  describe "#delete!" do
    it "writes exactly one active post_deletion and one :deleted event" do
      expect { post.delete!("spam") }.to change { post.post_deletions.count }.by(1)

      pd = post.post_deletions.sole
      expect(pd).to have_attributes(is_undeleted: false, deleter_id: CurrentUser.id, reason: "spam", undeleter_id: nil)
      expect(deleted_events(post)).to eq(1)
      expect(post.reload.is_deleted).to be(true)
    end

    it "does not create a post flag" do
      expect { post.delete!("spam") }.not_to(change { post.flags.count })
    end

    it "rolls back the post_deletion and is_deleted together when the event write fails" do
      allow(PostEvent).to receive(:add).and_raise("boom") # not StatementInvalid, so with_timeout won't swallow it

      expect { post.delete!("spam") }.to raise_error("boom")
      expect(post.reload.is_deleted).to be(false)
      expect(post.post_deletions.count).to eq(0)
    end
  end

  describe "#undelete!" do
    before { post.delete!("spam") }

    it "stamps the active row in place (no new row) and logs one :undeleted event" do
      expect { post.undelete! }.not_to(change { post.post_deletions.count })

      pd = post.post_deletions.sole.reload
      expect(pd).to have_attributes(is_undeleted: true, undeleter_id: CurrentUser.id)
      expect(pd.undeleted_at).to be_present
      expect(undeleted_events(post)).to eq(1)
      expect(post.reload.is_deleted).to be(false)
    end

    it "leaves no active deletion" do
      post.undelete!
      expect(described_class.find(post.id).current_deletion).to be_nil
    end
  end

  describe "#undelete! on a post with no deletion row" do
    subject(:orphan) { create(:deleted_post) }

    it "restores the post and logs the :undeleted event" do
      expect(orphan.current_deletion).to be_nil

      expect { orphan.undelete! }.to change { undeleted_events(orphan) }.by(1)
      expect(orphan.reload.is_deleted).to be(false)
    end
  end

  describe "re-delete (delete -> undelete -> delete)" do
    before do
      post.delete!("first")
      post.undelete!
      post.delete!("second")
    end

    it "appends a second deletion with exactly one active at a time" do
      expect(post.post_deletions.count).to eq(2)
      expect(post.post_deletions.where(is_undeleted: false).count).to eq(1)
      expect(post.reload.is_deleted).to be(true)
      expect(post.current_deletion.reason).to eq("second")
    end
  end

  describe "1:1 write invariant across a full lifecycle (reconcilable from events)" do
    it "matches :deleted events to post_deletions and :undeleted events to stamped rows" do
      post.delete!("a")
      post.undelete!
      post.delete!("b")
      post.undelete!
      post.delete!("c")

      expect(deleted_events(post)).to eq(post.post_deletions.count) # 3 deletes == 3 rows
      expect(undeleted_events(post)).to eq(post.post_deletions.where(is_undeleted: true).count) # 2 undeletes == 2 stamped
      expect(post.post_deletions.where(is_undeleted: false).count).to eq(1) # one still active
    end
  end
end
