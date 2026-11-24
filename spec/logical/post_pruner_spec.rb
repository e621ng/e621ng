# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostPruner do
  include_context "as admin"

  let(:window)   { Danbooru.config.unapproved_post_deletion_window }
  let(:uploader) { create(:user) }
  let(:template) { nil }

  before do
    allow(Danbooru.config.custom_configuration).to receive(:post_pruned_dmail_template).and_return(template)
  end

  def prune!
    described_class.new.prune!
  end

  describe "#prune!" do
    describe "post selection" do
      it "deletes a pending post older than the window" do
        post = create(:pending_post, created_at: (window + 1.day).ago)
        prune!
        expect(post.reload).to have_attributes(is_deleted: true, is_pending: false)
      end

      it "keeps a pending post still inside the window" do
        post = create(:pending_post, created_at: (window - 1.day).ago)
        prune!
        expect(post.reload).to have_attributes(is_deleted: false, is_pending: true)
      end

      it "keeps an approved post older than the window" do
        post = create(:post, created_at: (window + 1.day).ago)
        expect { prune! }.not_to change(PostFlag, :count)
        expect(post.reload.is_deleted).to be false
      end

      it "skips a post that is already deleted" do
        post = create(:deleted_post, is_pending: true, created_at: (window + 1.day).ago)
        expect { prune! }.not_to change(PostFlag, :count)
        expect(post.reload.is_deleted).to be true
      end

      it "follows the configured window" do
        allow(Danbooru.config.custom_configuration).to receive(:unapproved_post_deletion_window).and_return(3.days)
        old    = create(:pending_post, created_at: 4.days.ago)
        recent = create(:pending_post, created_at: 2.days.ago)
        prune!
        expect(old.reload.is_deleted).to be true
        expect(recent.reload.is_deleted).to be false
      end
    end

    describe "deletion record" do
      let!(:post) { create(:pending_post, uploader: uploader, created_at: (window + 1.day).ago) }

      it "creates a deletion flag naming the window, as the system user" do
        prune!
        flag = post.flags.last
        expect(flag).to have_attributes(is_deletion: true, reason: "Unapproved in #{window.inspect}", creator_id: User.system.id)
      end

      it "records the deletion event as the system user" do
        expect { prune! }.to change { PostEvent.where(post_id: post.id, action: :deleted, creator_id: User.system.id).count }.by(1)
      end

      it "counts the deletion against the uploader" do
        expect { prune! }.to change { uploader.user_status.reload.post_deleted_count }.by(1)
      end

      it "restores the current user afterwards" do
        user = CurrentUser.user
        prune!
        expect(CurrentUser.user).to eq(user)
      end
    end

    describe "uploader notification" do
      let!(:post) { create(:pending_post, uploader: uploader, created_at: (window + 1.day).ago) }

      context "without a template" do
        it "sends no dmail" do
          expect { prune! }.not_to change(Dmail, :count)
        end
      end

      context "with a template that has no body" do
        let(:template) { { title: "Post #%POST_ID% has been deleted", body: "" } }

        it "sends no dmail" do
          expect { prune! }.not_to change(Dmail, :count)
        end
      end

      context "with a template" do
        let(:template) { { title: "Post #%POST_ID% was pruned", body: "post #%POST_ID% by user #%UPLOADER_ID%" } }

        it "dmails the uploader from the system user with the placeholders filled in" do
          expect { prune! }.to change(Dmail, :count).by(1)
          expect(Dmail.last).to have_attributes(
            to_id: uploader.id,
            owner_id: uploader.id,
            from_id: User.system.id,
            title: "Post ##{post.id} was pruned",
            body: "post ##{post.id} by user ##{uploader.id}",
          )
        end

        it "sends one dmail per pruned post" do
          create(:pending_post, uploader: uploader, created_at: (window + 2.days).ago)
          create(:pending_post, uploader: uploader, created_at: 1.day.ago)
          expect { prune! }.to change { Dmail.where(to_id: uploader.id).count }.by(2)
        end
      end

      context "with a template that has no title" do
        let(:template) { { body: "pruned" } }

        it "falls back to the default title" do
          prune!
          expect(Dmail.last.title).to eq("Post ##{post.id} has been deleted")
        end
      end
    end

    describe "when a deletion flag cannot be created" do
      let(:template) { { body: "pruned" } }
      let!(:failing) { create(:pending_post, created_at: (window + 2.days).ago) }
      let!(:other)   { create(:pending_post, uploader: uploader, created_at: (window + 1.day).ago) }

      before do
        allow_any_instance_of(Post).to receive(:delete!).and_wrap_original do |original, *args| # rubocop:disable RSpec/AnyInstance
          raise PostFlag::Error, "nope" if original.receiver.id == failing.id
          original.call(*args)
        end
      end

      it "carries on with the remaining posts" do
        expect { prune! }.not_to raise_error
        expect(failing.reload.is_deleted).to be false
        expect(other.reload.is_deleted).to be true
      end

      it "does not notify the uploader of the post that failed" do
        prune!
        expect(Dmail.where(to_id: failing.uploader_id)).to be_empty
        expect(Dmail.where(to_id: uploader.id).count).to eq(1)
      end
    end

    describe "status-locked post" do
      let(:template) { { body: "pruned" } }
      let!(:post)    { create(:pending_post, is_status_locked: true, uploader: uploader, created_at: (window + 1.day).ago) }

      it "is left pending" do
        expect { prune! }.not_to change(PostFlag, :count)
        expect(post.reload).to have_attributes(is_deleted: false, is_pending: true)
      end

      it "does not tell the uploader it was deleted" do
        expect { prune! }.not_to change(Dmail, :count)
      end

      it "does not stop the remaining posts from being pruned" do
        other = create(:pending_post, uploader: uploader, created_at: (window + 2.days).ago)
        expect { prune! }.to change { Dmail.where(to_id: uploader.id).count }.by(1)
        expect(other.reload.is_deleted).to be true
      end
    end
  end
end
