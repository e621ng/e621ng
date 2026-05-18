# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     PostReplacement Status Predicates                       #
# --------------------------------------------------------------------------- #

RSpec.describe PostReplacement do
  include_context "as admin"

  # Simple string-comparison predicates — no DB needed.
  describe "#is_pending?" do
    it "returns true when status is 'pending'" do
      expect(build_stubbed(:post_replacement, status: "pending")).to be_is_pending
    end

    it "returns false when status is not 'pending'" do
      expect(build_stubbed(:post_replacement, status: "approved")).not_to be_is_pending
    end
  end

  describe "#is_backup?" do
    it "returns true when status is 'original'" do
      expect(build_stubbed(:post_replacement, status: "original")).to be_is_backup
    end

    it "returns false when status is not 'original'" do
      expect(build_stubbed(:post_replacement, status: "pending")).not_to be_is_backup
    end
  end

  describe "#is_approved?" do
    it "returns true when status is 'approved'" do
      expect(build_stubbed(:post_replacement, status: "approved")).to be_is_approved
    end

    it "returns false when status is not 'approved'" do
      expect(build_stubbed(:post_replacement, status: "pending")).not_to be_is_approved
    end
  end

  describe "#is_rejected?" do
    it "returns true when status is 'rejected'" do
      expect(build_stubbed(:post_replacement, status: "rejected")).to be_is_rejected
    end

    it "returns false when status is not 'rejected'" do
      expect(build_stubbed(:post_replacement, status: "pending")).not_to be_is_rejected
    end
  end

  describe "#is_promoted?" do
    it "returns true when status is 'promoted'" do
      expect(build_stubbed(:post_replacement, status: "promoted")).to be_is_promoted
    end

    it "returns false when status is not 'promoted'" do
      expect(build_stubbed(:post_replacement, status: "pending")).not_to be_is_promoted
    end
  end

  # is_current? and is_retired? compare md5 against the associated post — DB needed.
  describe "#is_current?" do
    it "returns true when the replacement md5 matches the post md5" do
      post = create(:post)
      replacement = create(:post_replacement, post: post, md5: post.md5)
      expect(replacement.is_current?).to be true
    end

    it "returns false when the replacement md5 differs from the post md5" do
      post = create(:post)
      replacement = create(:post_replacement, post: post, md5: "different_md5_value_here")
      expect(replacement.is_current?).to be false
    end
  end

  describe "#is_retired?" do
    it "returns true when approved and md5 no longer matches the post" do
      post = create(:post)
      replacement = create(:approved_post_replacement, post: post, md5: "other_md5_value")
      expect(replacement.is_retired?).to be true
    end

    it "returns false when approved and md5 still matches the post (is_current?)" do
      post = create(:post)
      replacement = create(:approved_post_replacement, post: post, md5: post.md5)
      expect(replacement.is_retired?).to be false
    end

    it "returns false when status is pending" do
      post = create(:post)
      replacement = create(:post_replacement, post: post, md5: "other_md5_value")
      expect(replacement.is_retired?).to be false
    end
  end
end
