# frozen_string_literal: true

require "rails_helper"

# Tests for the `update_reason` validator (validate :update_reason, on: :create),
# which sets the final `reason` text and, for the "inferior" reason, also updates
# the post's parent_id relationship.

RSpec.describe PostFlag do
  include_context "as admin"

  describe "update_reason (on: :create)" do
    describe "standard reason names" do
      it "has at least one configured flag reason" do
        expect(Danbooru.config.flag_reasons).not_to be_empty
      end

      Danbooru.config.flag_reasons.reject { |r| r[:name].to_s == "inferior" }.each do |reason_def|
        name = reason_def[:name].to_s

        it "sets reason to the mapped text for '#{name}'" do
          attrs = { reason_name: name }
          attrs[:note] = "Explanation." if reason_def[:require_explanation]
          flag = create(:post_flag, **attrs)
          expect(flag.reason).to eq(PostFlag::MAPPED_REASONS[name])
        end
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
