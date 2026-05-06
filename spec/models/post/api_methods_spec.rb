# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "ApiMethods" do
    describe "#status" do
      it "returns 'pending' for a pending post" do
        expect(create(:pending_post).status).to eq("pending")
      end

      it "returns 'deleted' for a deleted post" do
        expect(create(:deleted_post).status).to eq("deleted")
      end

      it "returns 'flagged' for a flagged post" do
        expect(create(:flagged_post).status).to eq("flagged")
      end

      it "returns 'active' for a normal post" do
        post = create(:post, is_pending: false, is_deleted: false, is_flagged: false)
        expect(post.status).to eq("active")
      end
    end

    describe "#hidden_attributes" do
      it "always hides pool_string and fav_string" do
        post = create(:post)
        expect(post.hidden_attributes).to include(:pool_string, :fav_string)
      end

      it "additionally hides md5 and file_ext when the post is not visible" do
        # A deleted post is not visible to non-staff
        CurrentUser.user    = create(:user)
        CurrentUser.ip_addr = "127.0.0.1"

        post = create(:deleted_post)
        expect(post.hidden_attributes).to include(:md5, :file_ext)
      ensure
        CurrentUser.user    = nil
        CurrentUser.ip_addr = nil
      end

      it "does not hide md5 and file_ext for staff on a deleted post" do
        post = create(:deleted_post)
        # Admin context is already set by include_context "as admin"
        expect(post.hidden_attributes).not_to include(:md5, :file_ext)
      end
    end

    describe "#thumbnail_attributes" do
      it "includes id, flags, tags, rating, file_ext, width, and height" do
        post = create(:post)
        attrs = post.thumbnail_attributes
        expect(attrs).to include(:id, :flags, :tags, :rating, :file_ext, :width, :height)
      end

      it "includes preview URL information for a post with a valid preview" do
        post = create(:post, file_ext: "jpg", image_width: 640, image_height: 480)
        attrs = post.thumbnail_attributes
        expect(attrs).to include(:preview_url)
      end
    end

    describe "#method_attributes" do
      it "includes has_sample and has_visible_children" do
        post = create(:post)
        expect(post.method_attributes).to include(:has_sample, :has_visible_children)
      end

      it "includes file_url, sample_url, and preview_file_url for visible posts" do
        post = create(:post)
        expect(post.method_attributes).to include(:file_url, :sample_url, :preview_file_url)
      end
    end
  end
end
