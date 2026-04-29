# frozen_string_literal: true

require "rails_helper"

# Tests for the `update_reason` validator (validate :update_reason, on: :create),
# which sets the final `reason` text and, for the "inferior" reason, also updates
# the post's parent_id relationship.

RSpec.describe PostFlag do
  include_context "as admin"

  describe "update_reason (on: :create)" do
    describe "standard reason names", skip: "This test is skipped on this fork" do
      it "sets reason to the mapped text for 'young_human'" do
        flag = create(:post_flag, reason_name: "young_human")
        expect(flag.reason).to eq(PostFlag::MAPPED_REASONS["young_human"])
      end

      it "sets reason to the mapped text for 'dnp_artist'" do
        flag = create(:post_flag, reason_name: "dnp_artist")
        expect(flag.reason).to eq(PostFlag::MAPPED_REASONS["dnp_artist"])
      end

      it "sets reason to the mapped text for 'pay_content'" do
        flag = create(:post_flag, reason_name: "pay_content")
        expect(flag.reason).to eq(PostFlag::MAPPED_REASONS["pay_content"])
      end

      it "sets reason to the mapped text for 'previously_deleted'" do
        flag = create(:post_flag, reason_name: "previously_deleted")
        expect(flag.reason).to eq(PostFlag::MAPPED_REASONS["previously_deleted"])
      end

      it "sets reason to the mapped text for 'real_porn'" do
        flag = create(:post_flag, reason_name: "real_porn")
        expect(flag.reason).to eq(PostFlag::MAPPED_REASONS["real_porn"])
      end

      it "sets reason to the mapped text for 'uploading_guidelines'" do
        flag = create(:post_flag, reason_name: "uploading_guidelines", note: "Explanation.")
        expect(flag.reason).to eq(PostFlag::MAPPED_REASONS["uploading_guidelines"])
      end

      it "sets reason to the mapped text for 'trace'" do
        flag = create(:post_flag, reason_name: "trace", note: "Explanation.")
        expect(flag.reason).to eq(PostFlag::MAPPED_REASONS["trace"])
      end

      it "sets reason to the mapped text for 'corrupt'" do
        flag = create(:post_flag, reason_name: "corrupt", note: "Explanation.")
        expect(flag.reason).to eq(PostFlag::MAPPED_REASONS["corrupt"])
      end
    end

    describe "'inferior' reason" do
      # parent_id is an attr_accessor consumed by validate_reason / update_reason
      # (both on: :create). It must be set on the instance *before* save so the
      # validation/callback hooks can read it.
      let(:parent_post) { create(:post) }

      def make_inferior_flag(child_post:, parent_id:)
        flag = build(:post_flag, post: child_post, reason_name: "inferior")
        flag.parent_id = parent_id
        flag.save!
        flag
      end

      it "sets reason to the inferior duplicate message" do
        child_post = create(:post)
        flag = make_inferior_flag(child_post: child_post, parent_id: parent_post.id)
        expect(flag.reason).to eq("Inferior version/duplicate of post ##{parent_post.id}")
      end

      it "updates post.parent_id to the given parent_id" do
        child_post = create(:post)
        make_inferior_flag(child_post: child_post, parent_id: parent_post.id)
        expect(child_post.reload.parent_id).to eq(parent_post.id)
      end

      it "removes the inverted relationship when parent_post is currently a child of the flagged post" do
        # Scenario: parent_post.parent_id == child_post.id (currently inverted)
        child_post = create(:post)
        parent_post.update_columns(parent_id: child_post.id)

        make_inferior_flag(child_post: child_post, parent_id: parent_post.id)

        # After fixing the inversion, parent_post should no longer be a child of child_post
        expect(parent_post.reload.parent_id).to be_nil
      end
    end

    describe "'deletion' reason" do
      it "leaves reason unchanged (NOP)" do
        flag = create(:deletion_post_flag)
        expect(flag.reason).to eq("Test deletion reason")
      end
    end
  end
end
