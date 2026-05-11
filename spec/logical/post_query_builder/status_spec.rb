# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "status: metatag" do
    describe "status:pending" do
      it "includes posts where is_pending is true" do
        post = create(:post)
        post.update_columns(is_pending: true)
        expect(run("status:pending")).to include(post)
      end

      it "excludes posts where is_pending is false" do
        post = create(:post)
        post.update_columns(is_pending: false)
        expect(run("status:pending")).not_to include(post)
      end
    end

    describe "status:flagged" do
      it "includes posts where is_flagged is true" do
        post = create(:post)
        post.update_columns(is_flagged: true)
        expect(run("status:flagged")).to include(post)
      end

      it "excludes posts where is_flagged is false" do
        post = create(:post)
        post.update_columns(is_flagged: false)
        expect(run("status:flagged")).not_to include(post)
      end
    end

    describe "status:modqueue" do
      it "includes a pending post" do
        post = create(:post)
        post.update_columns(is_pending: true)
        expect(run("status:modqueue")).to include(post)
      end

      it "includes a flagged post" do
        post = create(:post)
        post.update_columns(is_flagged: true)
        expect(run("status:modqueue")).to include(post)
      end

      it "excludes a post that is neither pending nor flagged" do
        post = create(:post)
        post.update_columns(is_pending: false, is_flagged: false)
        expect(run("status:modqueue")).not_to include(post)
      end
    end

    describe "status:deleted" do
      it "includes posts where is_deleted is true" do
        post = create(:post)
        post.update_columns(is_deleted: true)
        expect(run("status:deleted")).to include(post)
      end

      it "excludes posts where is_deleted is false" do
        post = create(:post)
        post.update_columns(is_deleted: false)
        expect(run("status:deleted")).not_to include(post)
      end
    end

    describe "status:active" do
      it "includes posts with no status flags set" do
        post = create(:post)
        post.update_columns(is_pending: false, is_deleted: false, is_flagged: false)
        expect(run("status:active")).to include(post)
      end

      it "excludes a pending post" do
        post = create(:post)
        post.update_columns(is_pending: true)
        expect(run("status:active")).not_to include(post)
      end

      it "excludes a deleted post" do
        post = create(:post)
        post.update_columns(is_deleted: true)
        expect(run("status:active")).not_to include(post)
      end

      it "excludes a flagged post" do
        post = create(:post)
        post.update_columns(is_flagged: true)
        expect(run("status:active")).not_to include(post)
      end
    end

    describe "status:all" do
      it "returns both active and deleted posts" do
        active = create(:post)
        active.update_columns(is_deleted: false)
        deleted = create(:post)
        deleted.update_columns(is_deleted: true)
        result = run("status:all")
        expect(result).to include(active, deleted)
      end
    end

    describe "status:any" do
      it "returns both active and pending posts" do
        active = create(:post)
        active.update_columns(is_pending: false)
        pending_post = create(:post)
        pending_post.update_columns(is_pending: true)
        result = run("status:any")
        expect(result).to include(active, pending_post)
      end
    end
  end

  describe "-status: (negated status metatag)" do
    describe "-status:pending" do
      it "excludes pending posts" do
        post = create(:post)
        post.update_columns(is_pending: true)
        expect(run("-status:pending")).not_to include(post)
      end

      it "includes non-pending posts" do
        post = create(:post)
        post.update_columns(is_pending: false)
        expect(run("-status:pending")).to include(post)
      end
    end

    describe "-status:flagged" do
      it "excludes flagged posts" do
        post = create(:post)
        post.update_columns(is_flagged: true)
        expect(run("-status:flagged")).not_to include(post)
      end

      it "includes non-flagged posts" do
        post = create(:post)
        post.update_columns(is_flagged: false)
        expect(run("-status:flagged")).to include(post)
      end
    end

    describe "-status:modqueue" do
      it "excludes pending posts" do
        post = create(:post)
        post.update_columns(is_pending: true, is_flagged: false)
        expect(run("-status:modqueue")).not_to include(post)
      end

      it "excludes flagged posts" do
        post = create(:post)
        post.update_columns(is_pending: false, is_flagged: true)
        expect(run("-status:modqueue")).not_to include(post)
      end

      it "includes posts that are neither pending nor flagged" do
        post = create(:post)
        post.update_columns(is_pending: false, is_flagged: false)
        expect(run("-status:modqueue")).to include(post)
      end
    end

    describe "-status:deleted" do
      it "excludes deleted posts" do
        post = create(:post)
        post.update_columns(is_deleted: true)
        expect(run("-status:deleted")).not_to include(post)
      end

      it "includes non-deleted posts" do
        post = create(:post)
        post.update_columns(is_deleted: false)
        expect(run("-status:deleted")).to include(post)
      end
    end

    describe "-status:active" do
      it "excludes posts where all flags are false" do
        post = create(:post)
        post.update_columns(is_pending: false, is_deleted: false, is_flagged: false)
        expect(run("-status:active")).not_to include(post)
      end

      it "includes a pending post" do
        post = create(:post)
        post.update_columns(is_pending: true)
        expect(run("-status:active")).to include(post)
      end

      it "includes a deleted post" do
        post = create(:post)
        post.update_columns(is_deleted: true)
        expect(run("-status:active")).to include(post)
      end

      it "includes a flagged post" do
        post = create(:post)
        post.update_columns(is_flagged: true)
        expect(run("-status:active")).to include(post)
      end
    end
  end
end
