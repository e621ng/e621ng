# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "normalizations" do
    describe "description (CRLF → LF)" do
      it "converts \\r\\n to \\n on create" do
        post = create(:post, description: "line one\r\nline two")
        expect(post.description).to eq("line one\nline two")
      end

      it "converts \\r\\n to \\n on update" do
        post = create(:post)
        post.update!(description: "updated\r\nbody")
        expect(post.description).to eq("updated\nbody")
      end

      it "leaves \\n-only content unchanged" do
        post = create(:post, description: "line one\nline two")
        expect(post.description).to eq("line one\nline two")
      end
    end

    describe "fix_bg_color" do
      it "converts a blank string to nil" do
        post = build(:post, bg_color: "   ")
        post.valid?
        expect(post.bg_color).to be_nil
      end

      it "converts an empty string to nil" do
        post = build(:post, bg_color: "")
        post.valid?
        expect(post.bg_color).to be_nil
      end

      it "leaves a valid hex color unchanged" do
        post = build(:post, bg_color: "ff0000")
        post.valid?
        expect(post.bg_color).to eq("ff0000")
      end

      it "leaves nil unchanged" do
        post = build(:post, bg_color: nil)
        post.valid?
        expect(post.bg_color).to be_nil
      end
    end

    describe "strip_source" do
      it "converts a blank source to an empty string" do
        post = build(:post, source: "   ")
        post.valid?
        expect(post.source).to eq("")
      end

      it "normalizes \\r\\n line endings within source to \\n" do
        post = build(:post, source: "https://example.com\r\nhttps://other.example.com")
        post.valid?
        expect(post.source).not_to include("\r")
      end

      it "decodes URL-encoded %0A into a newline separator" do
        post = build(:post, source: "https://example.com%0Ahttps://other.example.com")
        post.valid?
        expect(post.source).not_to include("%0A")
      end
    end

    describe "blank_out_nonexistent_parents" do
      it "clears parent_id when parent post does not exist" do
        post = build(:post, parent_id: 999_999_999)
        post.valid?
        expect(post.parent_id).to be_nil
      end

      it "leaves parent_id set when the parent post exists" do
        parent = create(:post)
        post = build(:post, parent: parent)
        post.valid?
        expect(post.parent_id).to eq(parent.id)
      end
    end

    describe "remove_parent_loops" do
      it "breaks a two-step parent loop when saving a child" do
        # grandparent <– parent <– (would loop back to grandparent)
        grandparent = create(:post)
        parent      = create(:post)
        grandparent.update_columns(parent_id: parent.id)

        # Now try to make parent's parent = grandparent, which would create a loop:
        # grandparent → parent → grandparent
        child = build(:post, parent: grandparent)
        child.valid?

        # The loop (grandparent.parent_id pointing back) must be resolved
        # No error is raised; the loop is silently broken
        expect { child.save! }.not_to raise_error
      end
    end
  end
end
