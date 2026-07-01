# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       PostReplacement Scopes                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostReplacement do
  include_context "as admin"

  # --------------------------------------------------------------------------
  # Status scopes
  # --------------------------------------------------------------------------
  describe ".pending" do
    let!(:pending)  { create(:post_replacement, status: "pending") }
    let!(:approved) { create(:approved_post_replacement) }

    it "includes pending replacements" do
      expect(PostReplacement.pending).to include(pending)
    end

    it "excludes non-pending replacements" do
      expect(PostReplacement.pending).not_to include(approved)
    end
  end

  describe ".rejected" do
    let!(:rejected) { create(:rejected_post_replacement) }
    let!(:pending)  { create(:post_replacement) }

    it "includes rejected replacements" do
      expect(PostReplacement.rejected).to include(rejected)
    end

    it "excludes non-rejected replacements" do
      expect(PostReplacement.rejected).not_to include(pending)
    end
  end

  describe ".approved" do
    let!(:approved) { create(:approved_post_replacement) }
    let!(:pending)  { create(:post_replacement) }

    it "includes approved replacements" do
      expect(PostReplacement.approved).to include(approved)
    end

    it "excludes non-approved replacements" do
      expect(PostReplacement.approved).not_to include(pending)
    end
  end

  # --------------------------------------------------------------------------
  # .for_user
  # --------------------------------------------------------------------------
  describe ".for_user" do
    let!(:creator_a)     { create(:user) }
    let!(:creator_b)     { create(:user) }
    let!(:replacement_a) { create(:post_replacement, creator: creator_a) }
    let!(:replacement_b) { create(:post_replacement, creator: creator_b) }

    it "returns replacements belonging to the given creator" do
      expect(PostReplacement.for_user(creator_a.id)).to include(replacement_a)
    end

    it "excludes replacements from other creators" do
      expect(PostReplacement.for_user(creator_a.id)).not_to include(replacement_b)
    end
  end

  # --------------------------------------------------------------------------
  # .for_uploader_on_approve
  # --------------------------------------------------------------------------
  describe ".for_uploader_on_approve" do
    let!(:uploader_a) { create(:user) }
    let!(:uploader_b) { create(:user) }

    # set_previous_uploader (before_create callback) copies post.uploader_id
    # into uploader_id_on_approve, so using distinct uploaders per post is enough.
    let!(:post_a) { create(:post, uploader: uploader_a) }
    let!(:post_b) { create(:post, uploader: uploader_b) }

    # Use a different creator so penalize_uploader_on_approve is not forced to false
    let!(:creator) { create(:user) }
    let!(:replacement_a) { create(:post_replacement, post: post_a, creator: creator) }
    let!(:replacement_b) { create(:post_replacement, post: post_b, creator: creator) }

    it "returns replacements whose uploader_id_on_approve matches" do
      expect(PostReplacement.for_uploader_on_approve(uploader_a.id)).to include(replacement_a)
    end

    it "excludes replacements with a different uploader_id_on_approve" do
      expect(PostReplacement.for_uploader_on_approve(uploader_a.id)).not_to include(replacement_b)
    end
  end

  # --------------------------------------------------------------------------
  # .penalized / .not_penalized
  # --------------------------------------------------------------------------
  describe ".penalized" do
    let!(:penalized)     { create(:approved_post_replacement).tap { |r| r.update_columns(penalize_uploader_on_approve: true) } }
    let!(:not_penalized) { create(:approved_post_replacement).tap { |r| r.update_columns(penalize_uploader_on_approve: false) } }

    it "includes penalized replacements" do
      expect(PostReplacement.penalized).to include(penalized)
    end

    it "excludes non-penalized replacements" do
      expect(PostReplacement.penalized).not_to include(not_penalized)
    end
  end

  describe ".not_penalized" do
    let!(:penalized)     { create(:approved_post_replacement).tap { |r| r.update_columns(penalize_uploader_on_approve: true) } }
    let!(:not_penalized) { create(:approved_post_replacement).tap { |r| r.update_columns(penalize_uploader_on_approve: false) } }

    it "includes non-penalized replacements" do
      expect(PostReplacement.not_penalized).to include(not_penalized)
    end

    it "excludes penalized replacements" do
      expect(PostReplacement.not_penalized).not_to include(penalized)
    end
  end

  # --------------------------------------------------------------------------
  # .visible
  # --------------------------------------------------------------------------
  describe ".visible" do
    let!(:member)   { create(:user) }
    let!(:janitor)  { create(:janitor_user) }
    let!(:active)   { create(:post_replacement, status: "pending") }
    let!(:own_rejected) { create(:rejected_post_replacement, creator: member) }
    let!(:other_rejected) { create(:rejected_post_replacement) }

    it "shows non-rejected replacements to an anonymous user" do
      expect(PostReplacement.visible(User.anonymous)).to include(active)
    end

    it "hides all rejected replacements from an anonymous user" do
      result = PostReplacement.visible(User.anonymous)
      expect(result).not_to include(own_rejected)
      expect(result).not_to include(other_rejected)
    end

    it "shows a member their own rejected replacements" do
      expect(PostReplacement.visible(member)).to include(own_rejected)
    end

    it "hides other users' rejected replacements from a member" do
      expect(PostReplacement.visible(member)).not_to include(other_rejected)
    end

    it "shows all replacements including rejected to a janitor" do
      result = PostReplacement.visible(janitor)
      expect(result).to include(active, own_rejected, other_rejected)
    end
  end
end
