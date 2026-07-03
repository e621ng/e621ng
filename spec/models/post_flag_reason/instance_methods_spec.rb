# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlagReason do
  include_context "as admin"

  describe "#applies_to_post?" do
    let(:post) { create(:post) }

    context "with no target_tag or target_date" do
      let(:reason) { build(:post_flag_reason, target_tag: nil, target_date: nil, target_date_kind: nil) }

      it "returns true" do
        expect(reason.applies_to_post?(post)).to be true
      end
    end

    context "with a positive target_tag" do
      let(:reason) { build(:post_flag_reason, target_tag: "flaggable_tag", target_date: nil, target_date_kind: nil) }

      it "returns true when the post has the tag" do
        tagged_post = create(:post, tag_string: "flaggable_tag")
        expect(reason.applies_to_post?(tagged_post)).to be true
      end

      it "returns false when the post does not have the tag" do
        expect(reason.applies_to_post?(post)).to be false
      end
    end

    context "with a negated target_tag (prefixed with -)" do
      let(:reason) { build(:post_flag_reason, target_tag: "-exempt_tag", target_date: nil, target_date_kind: nil) }

      it "returns false when the post has the tag" do
        tagged_post = create(:post, tag_string: "exempt_tag")
        expect(reason.applies_to_post?(tagged_post)).to be false
      end

      it "returns true when the post does not have the tag" do
        expect(reason.applies_to_post?(post)).to be true
      end
    end

    context "with target_date_kind 'after'" do
      let(:cutoff) { Date.new(2015, 1, 1) }
      let(:reason) { build(:post_flag_reason, target_tag: nil, target_date: cutoff, target_date_kind: "after") }

      it "returns true when the post was created after the target date" do
        post.update_columns(created_at: Date.new(2016, 6, 1))
        expect(reason.applies_to_post?(post)).to be true
      end

      it "returns false when the post was created on the target date" do
        post.update_columns(created_at: cutoff)
        expect(reason.applies_to_post?(post)).to be false
      end

      it "returns false when the post was created before the target date" do
        post.update_columns(created_at: Date.new(2014, 1, 1))
        expect(reason.applies_to_post?(post)).to be false
      end
    end

    context "with target_date_kind 'before'" do
      let(:cutoff) { Date.new(2015, 1, 1) }
      let(:reason) { build(:post_flag_reason, target_tag: nil, target_date: cutoff, target_date_kind: "before") }

      it "returns true when the post was created before the target date" do
        post.update_columns(created_at: Date.new(2014, 6, 1))
        expect(reason.applies_to_post?(post)).to be true
      end

      it "returns true when the post was created on the target date" do
        post.update_columns(created_at: cutoff)
        expect(reason.applies_to_post?(post)).to be true
      end

      it "returns false when the post was created after the target date" do
        post.update_columns(created_at: Date.new(2016, 1, 1))
        expect(reason.applies_to_post?(post)).to be false
      end
    end

    context "with both target_tag and target_date conditions" do
      let(:cutoff) { Date.new(2015, 1, 1) }
      let(:reason) { build(:post_flag_reason, target_tag: "required_tag", target_date: cutoff, target_date_kind: "after") }

      it "returns true when both conditions pass" do
        tagged_post = create(:post, tag_string: "required_tag")
        tagged_post.update_columns(created_at: Date.new(2016, 1, 1))
        expect(reason.applies_to_post?(tagged_post)).to be true
      end

      it "returns false when the tag condition fails even if the date condition passes" do
        post.update_columns(created_at: Date.new(2016, 1, 1))
        expect(reason.applies_to_post?(post)).to be false
      end

      it "returns false when the date condition fails even if the tag condition passes" do
        tagged_post = create(:post, tag_string: "required_tag")
        tagged_post.update_columns(created_at: Date.new(2014, 1, 1))
        expect(reason.applies_to_post?(tagged_post)).to be false
      end
    end
  end
end
