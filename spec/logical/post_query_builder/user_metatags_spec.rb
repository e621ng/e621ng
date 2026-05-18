# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "uploader metatag" do
    describe "user:name" do
      it "includes posts uploaded by the named user" do
        uploader = create(:user, name: "test_uploader_a")
        post = create(:post, uploader: uploader)
        expect(run("user:test_uploader_a")).to include(post)
      end

      it "excludes posts uploaded by a different user" do
        other = create(:user, name: "test_uploader_b")
        post = create(:post, uploader: other)
        expect(run("user:test_uploader_a")).not_to include(post)
      end
    end

    describe "-user:name" do
      it "excludes posts uploaded by the named user" do
        uploader = create(:user, name: "test_uploader_c")
        post = create(:post, uploader: uploader)
        expect(run("-user:test_uploader_c")).not_to include(post)
      end

      it "includes posts uploaded by a different user" do
        other = create(:user, name: "test_uploader_d")
        post = create(:post, uploader: other)
        expect(run("-user:test_uploader_c")).to include(post)
      end
    end
  end

  describe "approver metatag" do
    describe "approver:any" do
      it "includes posts with a non-null approver_id" do
        approver = create(:user)
        post = create(:post)
        post.update_columns(approver_id: approver.id)
        expect(run("approver:any")).to include(post)
      end

      it "excludes posts with no approver" do
        post = create(:post)
        post.update_columns(approver_id: nil)
        expect(run("approver:any")).not_to include(post)
      end
    end

    describe "approver:none" do
      it "includes posts with a null approver_id" do
        post = create(:post)
        post.update_columns(approver_id: nil)
        expect(run("approver:none")).to include(post)
      end

      it "excludes posts that have an approver" do
        approver = create(:user)
        post = create(:post)
        post.update_columns(approver_id: approver.id)
        expect(run("approver:none")).not_to include(post)
      end
    end

    describe "approver:name" do
      it "includes posts approved by the named user" do
        approver = create(:user, name: "test_approver_a")
        post = create(:post)
        post.update_columns(approver_id: approver.id)
        expect(run("approver:test_approver_a")).to include(post)
      end

      it "excludes posts approved by a different user" do
        other_approver = create(:user, name: "test_approver_b")
        post = create(:post)
        post.update_columns(approver_id: other_approver.id)
        expect(run("approver:test_approver_a")).not_to include(post)
      end
    end

    describe "-approver:name" do
      it "excludes posts approved by the named user" do
        approver = create(:user, name: "test_approver_c")
        post = create(:post)
        post.update_columns(approver_id: approver.id)
        expect(run("-approver:test_approver_c")).not_to include(post)
      end

      it "includes posts approved by a different user" do
        other = create(:user, name: "test_approver_d")
        post = create(:post)
        post.update_columns(approver_id: other.id)
        expect(run("-approver:test_approver_c")).to include(post)
      end
    end
  end

  describe "commenter metatag" do
    describe "commenter:any" do
      it "includes posts with a non-null last_commented_at" do
        post = create(:post)
        post.update_columns(last_commented_at: 1.day.ago)
        expect(run("commenter:any")).to include(post)
      end

      it "excludes posts with no comments" do
        post = create(:post)
        post.update_columns(last_commented_at: nil)
        expect(run("commenter:any")).not_to include(post)
      end
    end

    describe "commenter:none" do
      it "includes posts with a null last_commented_at" do
        post = create(:post)
        post.update_columns(last_commented_at: nil)
        expect(run("commenter:none")).to include(post)
      end

      it "excludes posts that have been commented on" do
        post = create(:post)
        post.update_columns(last_commented_at: 1.day.ago)
        expect(run("commenter:none")).not_to include(post)
      end
    end
  end

  describe "noter metatag" do
    describe "noter:any" do
      it "includes posts with a non-null last_noted_at" do
        post = create(:post)
        post.update_columns(last_noted_at: 1.day.ago)
        expect(run("noter:any")).to include(post)
      end

      it "excludes posts with no notes" do
        post = create(:post)
        post.update_columns(last_noted_at: nil)
        expect(run("noter:any")).not_to include(post)
      end
    end

    describe "noter:none" do
      it "includes posts with a null last_noted_at" do
        post = create(:post)
        post.update_columns(last_noted_at: nil)
        expect(run("noter:none")).to include(post)
      end

      it "excludes posts that have been noted" do
        post = create(:post)
        post.update_columns(last_noted_at: 1.day.ago)
        expect(run("noter:none")).not_to include(post)
      end
    end
  end
end
