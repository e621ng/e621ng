# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "SearchMethods" do
    describe ".pending" do
      it "returns pending posts" do
        pending_post = create(:pending_post)
        normal_post  = create(:post, is_pending: false)
        expect(Post.pending).to include(pending_post)
        expect(Post.pending).not_to include(normal_post)
      end
    end

    describe ".flagged" do
      it "returns flagged posts" do
        flagged_post = create(:flagged_post)
        normal_post  = create(:post, is_flagged: false)
        expect(Post.flagged).to include(flagged_post)
        expect(Post.flagged).not_to include(normal_post)
      end
    end

    describe ".pending_or_flagged" do
      it "includes both pending and flagged posts" do
        pending = create(:pending_post)
        flagged = create(:flagged_post)
        normal  = create(:post, is_pending: false, is_flagged: false)

        result = Post.pending_or_flagged
        expect(result).to include(pending, flagged)
        expect(result).not_to include(normal)
      end
    end

    describe ".deleted" do
      it "returns deleted posts" do
        deleted = create(:deleted_post)
        active  = create(:post, is_deleted: false)
        expect(Post.deleted).to include(deleted)
        expect(Post.deleted).not_to include(active)
      end
    end

    describe ".undeleted" do
      it "returns non-deleted posts" do
        deleted = create(:deleted_post)
        active  = create(:post, is_deleted: false)
        expect(Post.undeleted).to include(active)
        expect(Post.undeleted).not_to include(deleted)
      end
    end

    describe ".for_user" do
      it "returns posts belonging to the specified user" do
        user      = create(:user)
        own_post  = create(:post, uploader: user)
        other_post = create(:post)
        expect(Post.for_user(user.id)).to include(own_post)
        expect(Post.for_user(user.id)).not_to include(other_post)
      end
    end

    describe ".find_by(md5:)" do
      it "finds a post by its md5 hash" do
        post = create(:post)
        found = Post.find_by(md5: post.md5)
        expect(found).to eq(post)
      end

      it "returns nil when no post has the given md5" do
        expect(Post.find_by(md5: "0" * 32)).to be_nil
      end
    end

    describe ".has_notes" do
      it "returns posts that have been noted" do
        noted = create(:post)
        noted.update_columns(last_noted_at: Time.current)
        unnoted = create(:post, last_noted_at: nil)

        expect(Post.has_notes).to include(noted)
        expect(Post.has_notes).not_to include(unnoted)
      end
    end
  end
end
