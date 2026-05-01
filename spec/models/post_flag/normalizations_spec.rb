# frozen_string_literal: true

require "rails_helper"

# Tests for the `update_reason` validator (validate :update_reason, on: :create),
# which sets the final `reason` text and, for the "inferior" reason, also updates
# the post's parent_id relationship.

RSpec.describe PostFlag do
  include_context "as admin"

  describe "update_reason (on: :create)" do
    it "sets flag's reason to the flag reason text" do
      flag_reason = create(:post_flag_reason)
      attrs = { reason_name: flag_reason.name }
      attrs[:note] = "Explanation." if flag_reason.needs_explanation?
      flag = create(:post_flag, **attrs)
      expect(flag.reason).to eq(flag_reason.reason)
    end

    describe "'needs_parent_id' is set" do
      # parent_id is an attr_accessor consumed by validate_reason / update_reason
      # (both on: :create). It must be set on the instance *before* save so the
      # validation/callback hooks can read it.
      let(:parent_post) { create(:post) }

      def make_inferior_flag(child_post:, parent_id:)
        create(:needs_parent_id_post_flag_reason)
        flag = build(:needs_parent_id_post_flag, post: child_post)
        flag.parent_id = parent_id
        flag.save!
        flag
      end

      it "adds the post id to the reason message" do
        child_post = create(:post)
        flag = make_inferior_flag(child_post: child_post, parent_id: parent_post.id)
        expect(flag.reason).to eq("Duplicate or inferior version of another post (##{parent_post.id})")
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
